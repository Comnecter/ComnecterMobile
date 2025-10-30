plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    //TODO: Uncomment after Firebase project setup
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

android {
    namespace = "com.example.comnecter_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            versionNameSuffix = "-debug"
            signingConfig = signingConfigs.getByName("debug")
        }
        
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Configure flavors for different Firebase projects
    flavorDimensions += "environment"
    
    productFlavors {
        create("staging") {
            dimension = "environment"
            applicationId = "com.comnecter.mobile.staging"
            resValue("string", "app_name", "Comnecter Staging")
        }
        
        create("production") {
            dimension = "environment"
            applicationId = "com.comnecter.mobile.production"
            resValue("string", "app_name", "Comnecter")
        }
    }

    // Suppress Java 8 obsolete warnings
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:-options"))
    }
}

flutter {
    source = "../.."
}
