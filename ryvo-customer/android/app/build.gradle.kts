plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ryvo.customer"
    // Play requires API 36 for new apps and updates (31 Aug 2026).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must match the package name of the Play Console app. Permanent after the first upload.
        applicationId = "com.arcadexit.ryvo.customer"
        // Google Play (from 31 Aug 2026) rejects new apps below API 36.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Uncompressed native libs, 16 KB zip-aligned (Play page-size rule).
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    buildFeatures {
        dataBinding = true  // required by flutter_stripe
    }

    // flutter_stripe needs MaterialComponents to be on the classpath.
    dependencies {
        implementation("com.google.android.material:material:1.12.0")
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

tasks.matching { it.name == "bundleRelease" || it.name == "assembleRelease" }.configureEach {
    doFirst {
        if (!keystorePropertiesFile.exists()) {
            throw GradleException(
                "Missing android/key.properties. Create it for the upload keystore before building a Play App Bundle.",
            )
        }
        val storePath = keystoreProperties.getProperty("storeFile")
        val store = storePath?.let { project.file(it) }
        if (store == null || !store.exists()) {
            throw GradleException(
                "Upload keystore not found at $storePath. " +
                    "Set storeFile in android/key.properties to the shared .jks.",
            )
        }
    }
}

flutter {
    source = "../.."
}
