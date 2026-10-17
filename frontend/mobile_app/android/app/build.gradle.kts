import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException

val newBuildDir = rootProject.layout.projectDirectory.dir("../build")
layout.buildDirectory.value(newBuildDir.dir(project.name))

fun getKeystoreProperties(key: String): String {
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()

    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    } else {
        throw GradleException("keystore.properties file not found.")
    }

    return keystoreProperties.getProperty(key)
        ?: throw GradleException("Key '$key' not found in keystore.properties.")
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.thetact.ttact"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.thetact.ttact"
        minSdk = 27
        targetSdk = 36
        versionCode = 69
        versionName = "1.0.69"

        manifestPlaceholders["com.google.android.gms.permission.AD_ID"] = "true"

        ndk {
            abiFilters.add("arm64-v8a")
        }
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            storeFile = file(getKeystoreProperties("storeFile"))
            storePassword = getKeystoreProperties("storePassword")
            keyAlias = getKeystoreProperties("keyAlias")
            keyPassword = getKeystoreProperties("keyPassword")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isShrinkResources = true
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            // ffmpeg_kit and other prebuilt .so files ship without debug symbols.
            // Suppress the strip failure so the release build completes successfully.
            useLegacyPackaging = false
            keepDebugSymbols.add("**/*.so")
        }
    }

    // Tell Crashlytics to upload native .so debug symbols on every release build.
    firebaseCrashlytics {
        nativeSymbolUploadEnabled = true
        unstrippedNativeLibsDir = "build/intermediates/merged_native_libs/release/out/lib"
    }
}

// Set JVM target via KotlinCompile tasks — the correct approach when android.newDsl=false.
// kotlinOptions{} inside android{} is removed in Kotlin 2.3+; compilerOptions{} inside
// android{} only exists in the new DSL (android.newDsl=true). Task-based config works in both.
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.gms:play-services-ads:23.6.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Force a consistent CameraX version across all transitive dependencies.
    // mobile_scanner ^7.x requires CameraX 1.4.x; pinning to 1.3.x causes
    // NoSuchFieldError on Camera2Config$Companion at runtime.
    val cameraXVersion = "1.6.2"
    implementation("androidx.camera:camera-core:$cameraXVersion")
    implementation("androidx.camera:camera-camera2:$cameraXVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraXVersion")
    implementation("androidx.camera:camera-video:$cameraXVersion")
    implementation("androidx.camera:camera-view:$cameraXVersion")
    implementation("androidx.camera:camera-extensions:$cameraXVersion")
}

// Propagate Java and Kotlin compile settings to all plugin subprojects.
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library")) {
            configure<com.android.build.gradle.BaseExtension> {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
            }
        }
    }
}
