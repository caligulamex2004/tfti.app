import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'theme_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _usernameController =
      TextEditingController(); // NEW: Username controller
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
    _usernameController.dispose(); // Dispose new controller
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

  Future<void> _saveDeviceToken(User user) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint("✅ FCM Token saved successfully");
      }
    } catch (e) {
      debugPrint("❌ Error saving FCM token: $e");
    }
  }

  // UPDATED: Now uses a transaction to claim the username
  Future<void> _ensureUserDocExists(
    User user,
    String enteredName,
    String enteredUsername,
  ) async {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final docSnapshot = await userDoc.get();

    String finalName = enteredName;
    if (finalName.isEmpty) {
      finalName = user.phoneNumber ?? "Unknown User";
    }

    if (!docSnapshot.exists) {
      // BRAND NEW USER: Run a transaction to safely claim username and create profile
      String cleanUsername = enteredUsername.trim().toLowerCase();
      if (cleanUsername.startsWith('@'))
        cleanUsername = cleanUsername.substring(1);

      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final usernameRef = FirebaseFirestore.instance
              .collection('usernames')
              .doc(cleanUsername);
          final nameDoc = await transaction.get(usernameRef);

          // Failsafe: If the username was snatched between the pre-flight check and SMS entry
          if (nameDoc.exists) {
            cleanUsername =
                "${cleanUsername}_${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}";
            final fallbackRef = FirebaseFirestore.instance
                .collection('usernames')
                .doc(cleanUsername);
            transaction.set(fallbackRef, {'uid': user.uid});
          } else {
            transaction.set(usernameRef, {'uid': user.uid});
          }

          transaction.set(userDoc, {
            'uid': user.uid,
            'phoneNumber': user.phoneNumber,
            'displayName': finalName,
            'username': cleanUsername,
            'avatarColor': Colors.blue.toARGB32(),
            'createdAt': FieldValue.serverTimestamp(),
            'agreedToToS': _agreedToToS,
            'agreedToPrivacy': _agreedToPrivacy,
          }, SetOptions(merge: true));
        });

        await user.updateDisplayName(finalName);
      } catch (e) {
        debugPrint("Error creating user and claiming username: $e");
      }
    } else {
      // EXISTING USER LOGGING IN: Just ensure phone number is patched
      final data = docSnapshot.data();
      if (data == null ||
          (!data.containsKey('phone') && !data.containsKey('phoneNumber'))) {
        await userDoc.set({
          'phoneNumber': user.phoneNumber,
        }, SetOptions(merge: true));
      }
    }
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
      if (cleanName.startsWith('@')) cleanName = cleanName.substring(1);

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

      setState(() => _isLoading = true);

      try {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: _completePhoneNumber)
            .limit(1)
            .get();

        final bool accountExists = query.docs.isNotEmpty;

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
          String cleanName = _usernameController.text.trim().toLowerCase();
          if (cleanName.startsWith('@')) cleanName = cleanName.substring(1);

          final usernameDoc = await FirebaseFirestore.instance
              .collection('usernames')
              .doc(cleanName)
              .get();
          if (usernameDoc.exists) {
            setState(() => _isLoading = false);
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
        setState(() => _isLoading = false);
        debugPrint("Error during pre-flight check: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Network error. Please try again.")),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _completePhoneNumber,
      forceResendingToken: isResend ? _resendToken : null,

      verificationCompleted: (PhoneAuthCredential credential) async {
        final currentName = _nameController.text.trim();
        final currentUsername = _usernameController.text.trim(); // NEW

        try {
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          final user = userCredential.user;
          if (user != null) {
            await _ensureUserDocExists(user, currentName, currentUsername);
            await _saveDeviceToken(user);
          }
        } catch (e) {
          debugPrint("Auto-verify error: $e");
        }
      },

      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;

        setState(() => _isLoading = false);
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
    if (_otpController.text.isEmpty) return;
    setState(() => _isLoading = true);

    final currentName = _nameController.text.trim();
    final currentUsername = _usernameController.text.trim(); // NEW

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
        await _ensureUserDocExists(user, currentName, currentUsername);
        await _saveDeviceToken(user);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid Code. Try again.")));
    }
  }

  Widget _buildAgreementCheckbox(
    String text,
    bool value,
    Function(bool?) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: primaryColor,
            side: BorderSide(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
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
                              _buildTextField(
                                controller: _nameController,
                                label: "Pick a display name",
                                icon: Icons.person_outline,
                                maxLength: 50,
                              ),
                              const SizedBox(height: 16),
                              // NEW: Username Field
                              _buildTextField(
                                controller: _usernameController,
                                label: "Pick a username",
                                icon: Icons.alternate_email,
                                prefixText: "@ ",
                                maxLength: 20,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // --- PHONE FIELD (BOTH MODES) ---
                            IntlPhoneField(
                              controller: _phoneController,
                              initialCountryCode: 'US',
                              dropdownIconPosition: IconPosition.trailing,
                              dropdownIcon: Icon(
                                Icons.arrow_drop_down,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: "Phone Number",
                                labelStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                              ),
                              onChanged: (phone) {
                                _completePhoneNumber = phone.completeNumber;
                              },
                            ),

                            // --- SIGN UP ONLY CHECKBOXES ---
                            if (!_isLoginMode) ...[
                              const SizedBox(height: 16),
                              _buildAgreementCheckbox(
                                "I agree to the Terms of Service",
                                _agreedToToS,
                                (val) =>
                                    setState(() => _agreedToToS = val ?? false),
                              ),
                              const SizedBox(height: 8),
                              _buildAgreementCheckbox(
                                "I agree to the Privacy Policy",
                                _agreedToPrivacy,
                                (val) => setState(
                                  () => _agreedToPrivacy = val ?? false,
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // --- DYNAMIC BUTTON ---
                            _buildButton(
                              text: _isLoginMode
                                  ? "Get Login Code"
                                  : "Sign Up & Get Login Code",
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
                            _buildTextField(
                              controller: _otpController,
                              label: "6-Digit Code",
                              icon: Icons.lock_outline,
                              isNumber: true,
                            ),
                            const SizedBox(height: 24),
                            _buildButton(
                              text: "Verify & Enter",
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
                              onPressed: () => setState(() {
                                _codeSent = false;
                                _isLoading = false;
                                _timer?.cancel();
                              }),
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

  // UPDATED: Now supports prefix text and max lengths cleanly
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    String? prefixText,
    int? maxLength,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        prefixIcon: Icon(icon, color: primaryColor),
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        filled: true,
        fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        counterText: "", // Hides the max length counter natively
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: themeProvider.onPrimaryColor,
          disabledBackgroundColor: primaryColor.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: onPressed == null ? 0 : 2,
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: themeProvider.onPrimaryColor,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
