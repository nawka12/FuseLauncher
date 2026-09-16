// Versions match what the Flutter build already pins, so both trees can share
// the same Gradle/AGP/Kotlin install while the migration is in progress.
plugins {
    id("com.android.application") version "8.13.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20" apply false
}
