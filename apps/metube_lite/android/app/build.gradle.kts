import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// توقيع release من key.properties (خارج git) — راجع docs/plan/02-TRD.md §4
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.yasir.metubelite"
    // مثبت صراحة (TRD §4) — بموازاة Super.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // إلزامي لـ flutter_local_notifications (م-9) — TRD §4.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.yasir.metubelite"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // **فخ مصطاد على جهاز المالك (2026-09-01):** مُنقّي الموارد
            // يحذف كل `drawable/audio_service_*` لأن لا شيء يشير إليها
            // ستاتيكياً — و`audio_service` يبحث عنها **بالاسم وقت
            // التشغيل** (`getIdentifier`). النتيجة في نسخة release فقط:
            // `IllegalArgumentException: You must specify an icon resource
            // id to build a CustomAction` عند كل تشغيل ⇒ **لا إشعار وسائط
            // ولا أزرار شاشة قفل إطلاقاً**، بلا أي عطل ظاهر في الواجهة.
            // أُثبت بـ `aapt2 dump resources`: صفر مورد audio_service.
            // التنقية توفّر أقل من ميجابايت من 41 — لا تساوي عطلاً صامتاً.
            isShrinkResources = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
