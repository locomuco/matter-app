# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Play Store deferred components — not used outside Play Store, safe to ignore
-dontwarn com.google.android.play.core.**

# CHIP / Matter SDK — keep all JNI-bound classes and their native methods
-keep class chip.** { *; }
-keep class matter.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# Gson used by matter.jsontlv
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# org.json used by AttributeState.getJson()
-keep class org.json.** { *; }

# Kotlin coroutines
-keepnames class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
