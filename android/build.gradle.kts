buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Gunakan tanda kurung ("...") untuk Kotlin
        // Versi Gradle Tools
        classpath("com.android.tools.build:gradle:8.1.0") 
        
        // Versi Kotlin (Sesuaikan dengan versi Flutter Anda, 1.9.0 biasanya aman untuk Flutter terbaru)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")
        
        // Plugin Google Services (WAJIB ADA)
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Konfigurasi direktori build (Sintaks Kotlin)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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