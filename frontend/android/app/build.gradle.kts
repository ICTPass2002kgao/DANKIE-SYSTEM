import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException 

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
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.thetact.ttact"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8 // Changed to 1.8 for desugaring compatibility
        targetCompatibility = JavaVersion.VERSION_1_8 // Changed to 1.8 for desugaring compatibility
        
        // 👇 ADDED THIS LINE 👇
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.thetact.ttact"
        minSdk = 27
        targetSdk = 35
        versionCode = 45
        versionName = "1.0.45"
        
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
}

flutter {
    source = "../.."
}
dependencies {
    implementation("com.google.android.gms:play-services-ads:22.6.0")

    // 👇 UPDATED VERSION FROM 2.0.4 TO 2.1.4 👇
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

configurations.all {
    resolutionStrategy {
        force("androidx.camera:camera-core:1.5.0")
        force("androidx.camera:camera-camera2:1.5.0")
        force("androidx.camera:camera-lifecycle:1.5.0")
        force("androidx.camera:camera-video:1.5.0")
        force("androidx.camera:camera-view:1.5.0")
        force("androidx.camera:camera-extensions:1.5.0")
    }
}