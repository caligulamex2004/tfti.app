# Flutter wrapper & engine rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.play.core.**

# Keep source file names and line numbers for readable stack traces in Play Console
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# image_cropper (UCrop & OkHttp optional transitive warnings)
-dontwarn com.yalantis.ucrop**
-keep class com.yalantis.ucrop** { *; }
-keep interface com.yalantis.ucrop** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# flutter_image_compress
-keep class com.fluttercandies.flutter_image_compress.** { *; }

# app_badge_plus (uses reflection/OEM launcher implementations for badges)
-keep class me.liolin.app_badge_plus.** { *; }

# mobile_scanner / Google ML Kit Barcode Scanning
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# RevenueCat / Play Billing
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.amazon.**
