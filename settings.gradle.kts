pluginManagement {

    val versionOfToolchainsFoojayResolver: String by extra

    repositories {
        gradlePluginPortal()
        mavenCentral()
    }

    plugins {
        id("org.gradle.toolchains.foojay-resolver-convention") version versionOfToolchainsFoojayResolver
    }
}

include("templates:kotlinApp")
rootProject.name = "templates"
