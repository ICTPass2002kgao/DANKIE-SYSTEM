allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Force a single CameraX version across all modules to prevent
    // NoSuchFieldError: Camera2Config$Companion at runtime.
    configurations.all {
        resolutionStrategy {
            val cameraXVersion = "1.3.4"
            force("androidx.camera:camera-core:$cameraXVersion")
            force("androidx.camera:camera-camera2:$cameraXVersion")
            force("androidx.camera:camera-lifecycle:$cameraXVersion")
            force("androidx.camera:camera-video:$cameraXVersion")
            force("androidx.camera:camera-view:$cameraXVersion")
            force("androidx.camera:camera-extensions:$cameraXVersion")
        }
    }
}

val newBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}