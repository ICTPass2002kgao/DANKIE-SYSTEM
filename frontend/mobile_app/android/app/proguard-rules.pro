# --- FFmpegKit Rules (Prevent Obfuscation) ---
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.google.ads.interactivemedia.** { *; }

# Prevent native method stripping
-keepclasseswithmembernames class * {
    native <methods>;
}
