# Fix Stripe Push Provisioning Missing Classes
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.android.pushProvisioning.**

-keep class com.reactnativestripesdk.pushprovisioning.** { *; }
-dontwarn com.reactnativestripesdk.pushprovisioning.**

# Keep Kotlin metadata
-keep class kotlinx.** { *; }
-dontwarn kotlinx.**

# Prevent shrinking Flutter auto-generated classes
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
