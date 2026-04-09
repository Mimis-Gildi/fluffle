val useJavaVersion: String by project

plugins {
    alias(libs.plugins.kotlin.jvm)
    application
}

repositories {
    mavenCentral()
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(useJavaVersion))
    }
}

application {
    mainClass.set("me.lugaru.vitr.fluffle.ClaudeKt")
}
