pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.2") apply false
    id("com.google.firebase.crashlytics") version("3.0.2") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")

// Force all subprojects to use the same CameraX version.
// Without this, transitive deps (mobile_scanner, camera plugin) can each
// pull a different version, causing NoSuchFieldError on Camera2Config$Companion.
gradle.allprojects {
    configurations.all {
        resolutionStrategy {
            val cameraXVersion = "1.6.2"
            force("androidx.camera:camera-core:$cameraXVersion")
            force("androidx.camera:camera-camera2:$cameraXVersion")
            force("androidx.camera:camera-lifecycle:$cameraXVersion")
            force("androidx.camera:camera-video:$cameraXVersion")
            force("androidx.camera:camera-view:$cameraXVersion")
            force("androidx.camera:camera-extensions:$cameraXVersion")
        }
    }
}