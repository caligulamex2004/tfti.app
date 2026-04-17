import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/theme_provider.dart';
import '../utils/auth_service.dart';
import '../components/auth/auth_ui_components.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String _completePhoneNumber = "";
  String? _verificationId;
  int? _resendToken;
  bool _codeSent = false;
  bool _isLoading = false;

  bool _isLoginMode = true;
  bool _agreedToToS = false;
  bool _agreedToPrivacy = false;

  Timer? _timer;
  int _start = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _start = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  Future<void> _verifyPhone({bool isResend = false}) async {
    // 1. Validation for Sign Up mode
    if (!_isLoginMode && !isResend) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please tell us what to call you.")),
        );
        return;
      }

      if (_usernameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please pick a username.")),
        );
        return;
      }

      String cleanName = _usernameController.text.trim().toLowerCase();
      if (cleanName.startsWith('@')) {
        cleanName = cleanName.substring(1);
      }

      final regex = RegExp(r'^[a-z0-9.\-_]{3,20}$');
      if (!regex.hasMatch(cleanName)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Username must be 3-20 characters: letters, numbers, periods, dashes, or underscores.",
            ),
          ),
        );
        return;
      }

      if (!_agreedToToS || !_agreedToPrivacy) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "You must agree to the Terms and Privacy Policy to sign up.",
            ),
          ),
        );
        return;
      }
    }

    // 2. Phone validation and Pre-flight DB checks
    if (!isResend) {
      if (_completePhoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid phone number.")),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final bool accountExists = await AuthService.checkPhoneExists(
          _completePhoneNumber,
        );

        if (_isLoginMode && !accountExists) {
          // They tried to log in, but no account exists. Bump to Sign Up.
          setState(() {
            _isLoading = false;
            _isLoginMode = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("No account found! Please sign up first."),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        } else if (!_isLoginMode && accountExists) {
          // They tried to sign up, but an account already exists. Bump to Log In.
          setState(() {
            _isLoading = false;
            _isLoginMode = true;
            _nameController.clear();
            _usernameController.clear();
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Account already exists! Please log in."),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        } else if (!_isLoginMode && !accountExists) {
          // Perfect sign up attempt! Let's do a fast pre-flight check on the username
          final bool usernameExists = await AuthService.checkUsernameExists(
            _usernameController.text,
          );

          if (usernameExists) {
            setState(() {
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("That username is already taken!"),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        debugPrint("Error during pre-flight check: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Network error. Please try again.")),
          );
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _completePhoneNumber,
      forceResendingToken: isResend ? _resendToken : null,

      verificationCompleted: (PhoneAuthCredential credential) async {
        final currentName = _nameController.text.trim();
        final currentUsername = _usernameController.text.trim();

        try {
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          final user = userCredential.user;
          if (user != null) {
            await AuthService.ensureUserDocExists(
              user: user,
              enteredName: currentName,
              enteredUsername: currentUsername,
              agreedToToS: _agreedToToS,
              agreedToPrivacy: _agreedToPrivacy,
            );
            await AuthService.saveDeviceToken(user);
          }
        } catch (e) {
          debugPrint("Auto-verify error: $e");
        }
      },

      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
        });
        String msg = "Error ${e.code}: ${e.message}";
        if (e.code == 'invalid-phone-number') {
          msg = "That phone number doesn't look right.";
        } else if (e.code == 'too-many-requests') {
          msg = "Whoa! Too many tries. Wait a bit.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      },

      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isLoading = false;
          });
          _startTimer();
        }
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _canResend = true;
          });
        }
      },
    );
  }

  Future<void> _signInWithOTP() async {
    if (_otpController.text.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final currentName = _nameController.text.trim();
    final currentUsername = _usernameController.text.trim();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null) {
        await AuthService.ensureUserDocExists(
          user: user,
          enteredName: currentName,
          enteredUsername: currentUsername,
          agreedToToS: _agreedToToS,
          agreedToPrivacy: _agreedToPrivacy,
        );
        await AuthService.saveDeviceToken(user);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid Code. Try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.appGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Symbols.how_to_vote,
                    size: 80,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "tfti.app",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),

                  Card(
                    elevation: isDark ? 2 : 8,
                    color: Theme.of(context).cardColor,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: isDark
                          ? BorderSide(color: Colors.grey.shade800)
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            _codeSent
                                ? "Verify It's You"
                                : (_isLoginMode
                                      ? "Welcome Back"
                                      : "Join the Squad"),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _codeSent
                                ? "We sent a code to ${_phoneController.text}"
                                : (_isLoginMode
                                      ? "Enter your number to login."
                                      : "Create an account to get started."),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 30),

                          if (!_codeSent) ...[
                            // --- SIGN UP ONLY FIELDS ---
                            if (!_isLoginMode) ...[
                              AuthTextField(
                                controller: _nameController,
                                label: "Pick a display name",
                                icon: Icons.person_outline,
                                maxLength: 50,
                              ),
                              const SizedBox(height: 16),
                              AuthTextField(
                                controller: _usernameController,
                                label: "Pick a username",
                                icon: Icons.alternate_email,
                                prefixText: "@ ",
                                maxLength: 20,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // --- PHONE FIELD (BOTH MODES) ---
                            AuthPhoneField(
                              controller: _phoneController,
                              onChanged: (completeNumber) {
                                _completePhoneNumber = completeNumber;
                              },
                            ),

                            // --- SIGN UP ONLY CHECKBOXES ---
                            if (!_isLoginMode) ...[
                              const SizedBox(height: 16),
                              AuthCheckbox(
                                text: "I agree to the Terms of Service",
                                value: _agreedToToS,
                                onChanged: (val) {
                                  setState(() {
                                    _agreedToToS = val ?? false;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              AuthCheckbox(
                                text: "I agree to the Privacy Policy",
                                value: _agreedToPrivacy,
                                onChanged: (val) {
                                  setState(() {
                                    _agreedToPrivacy = val ?? false;
                                  });
                                },
                              ),
                            ],

                            const SizedBox(height: 24),

                            // --- DYNAMIC BUTTON ---
                            AuthButton(
                              text: _isLoginMode
                                  ? "Get Login Code"
                                  : "Sign Up & Get Login Code",
                              isLoading: _isLoading,
                              onPressed:
                                  (!_isLoginMode &&
                                      (!_agreedToToS || !_agreedToPrivacy))
                                  ? null
                                  : () => _verifyPhone(isResend: false),
                            ),

                            const SizedBox(height: 16),

                            // --- TOGGLE MODE FOOTER ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLoginMode
                                      ? "Don't have an account?"
                                      : "Already have an account?",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isLoginMode = !_isLoginMode;
                                    });
                                  },
                                  child: Text(
                                    _isLoginMode ? "Sign Up" : "Log In",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // --- OTP VERIFICATION UI ---
                            AuthTextField(
                              controller: _otpController,
                              label: "6-Digit Code",
                              icon: Icons.lock_outline,
                              isNumber: true,
                            ),
                            const SizedBox(height: 24),
                            AuthButton(
                              text: "Verify & Enter",
                              isLoading: _isLoading,
                              onPressed: _signInWithOTP,
                            ),
                            const SizedBox(height: 16),
                            if (_canResend)
                              TextButton.icon(
                                onPressed: () => _verifyPhone(isResend: true),
                                icon: const Icon(Icons.refresh),
                                label: const Text("Resend Code"),
                              )
                            else
                              Text(
                                "Resend code in $_start s",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _codeSent = false;
                                  _isLoading = false;
                                  _timer?.cancel();
                                });
                              },
                              child: const Text("Change Phone Number"),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
