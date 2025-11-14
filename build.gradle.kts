val useJavaVersion: String by project

plugins {
    `kotlin-dsl`
}

allprojects {
    repositories {
        mavenCentral()
    }
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(useJavaVersion))
        vendor.set(JvmVendorSpec.ADOPTIUM)
    }
}

dependencies {
    implementation(gradleApi())
    implementation(platform(kotlin("bom")))
}

tasks.named<Jar>("jar") {
    enabled = false
}

