import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Üretim imza bilgileri (keystore şifreleri) KAYNAK KODA KOMMİTLENMEZ ve
// tercihen DEPO DIŞINDA tutulur. Aranma sırası:
//   1) GG_RELEASE_KEY_PROPERTIES ortam değişkeni (CI için tam dosya yolu)
//   2) C:/GuncelGundem-Release-Secrets/android/release-key.properties (yerel üretim makinesi)
//   3) android/key.properties (eski yol; .gitignore ile dışlanmıştır)
// Hiçbiri yoksa release derlemesi debug anahtarına düşer; MAĞAZA YÜKLEMESİ İÇİN
// bu kabul edilmez (bkz. ANDROID-PLAY-RELEASE-REPORT.md).
val keystoreProperties = Properties()
val keystoreCandidates = listOfNotNull(
    System.getenv("GG_RELEASE_KEY_PROPERTIES")?.let { file(it) },
    file("C:/GuncelGundem-Release-Secrets/android/release-key.properties"),
    rootProject.file("key.properties"),
)
val keystorePropertiesFile = keystoreCandidates.firstOrNull { it.exists() }
if (keystorePropertiesFile != null) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    logger.lifecycle("Release signing config: ${keystorePropertiesFile.absolutePath}")
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "tr.guncelgundem.guncelgundem"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "tr.guncelgundem.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Üretim imzası mevcutsa onu kullan; yoksa `flutter run --release`
            // geliştirici için çalışmaya devam etsin diye debug anahtarına düşer.
            // Mağazaya yüklenecek AAB için key.properties ZORUNLUDUR.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 ile ölü kod ve kaynak eleme. Mevcut mimari (Dio/Material/
            // Flutter plugin'leri) reflection kullanmaz; agresif kurallar
            // eklenmedi. İhtiyaç çıkarsa proguard-rules.pro genişletilebilir.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
