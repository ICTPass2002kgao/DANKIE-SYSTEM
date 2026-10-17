# --- FFmpegKit Rules (Prevent Obfuscation) ---
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.google.ads.interactivemedia.** { *; }

# Prevent native method stripping
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- CameraX Rules ---
# Preserve Camera2Config and its Kotlin Companion object.
# R8 can strip the Companion field when it considers it unreachable via static
# analysis, causing NoSuchFieldError: No field Companion of type
# Landroidx/camera/camera2/Camera2Config$Companion at runtime.
-keep class androidx.camera.camera2.Camera2Config { *; }
-keep class androidx.camera.camera2.Camera2Config$* { *; }
-keep class androidx.camera.camera2.Camera2Config$Companion { *; }

# Preserve all CameraX core classes used reflectively by mobile_scanner
-keep class androidx.camera.core.** { *; }
-keep class androidx.camera.lifecycle.** { *; }
-keep class androidx.camera.view.** { *; }
-keep class androidx.camera.video.** { *; }
-keep class androidx.camera.extensions.** { *; }
-dontwarn androidx.camera.**
