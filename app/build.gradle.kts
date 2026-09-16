import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Release signing lives outside the repo, same arrangement as the Flutter build:
// copy key.properties.example to native/key.properties and point it at a keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) keystorePropertiesFile.inputStream().use { load(it) }
}

android {
    namespace = "com.kayfahaarukku.fuselauncher"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.kayfahaarukku.fuselauncher"
        minSdk = 24
        targetSdk = 36
        versionCode = 25
        versionName = "1.4.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin {
        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }

    buildFeatures {
        compose = true
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Debug installs beside the shipped Flutter build instead of replacing
        // it. A different application id means a different sandbox, so the
        // migration off Flutter's prefs cannot run here - test that with a
        // build that keeps the real id.
        debug {
            applicationIdSuffix = ".native"
            versionNameSuffix = "-native"
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Signed with the debug key, so this APK could never replace the
                // shipped app anyway - the signatures do not match and the install
                // is refused. Take the debug build's id as well, so it installs
                // beside the real one for testing instead of failing outright, and
                // so a keyless build can never be mistaken for a publishable one.
                logger.warn("WARNING: native/key.properties is missing - building a sideload-only release, id .native, signed with the debug key. Do not publish this APK.")
                applicationIdSuffix = ".native"
                versionNameSuffix = "-native"
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
        getByName("test").java.srcDirs("src/test/kotlin")
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.collection:collection-ktx:1.4.5")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.fragment:fragment-ktx:1.8.5")
    implementation("androidx.biometric:biometric:1.1.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")

    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation("junit:junit:4.13.2")
    // org.json ships in the Android platform but not on the JVM test classpath.
    testImplementation("org.json:json:20240303")
}
