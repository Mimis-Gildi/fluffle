/* rdd13r 2025-11-14
Mimis v3
*/

pluginManagement {
    val versionOfToolchainsFoojayResolver: String by extra

    repositories {
        gradlePluginPortal()
        mavenCentral()
    }

    plugins {
        id("org.gradle.toolchains.foojay-resolver-convention") version versionOfToolchainsFoojayResolver
    }

    includeBuild("build-logic")
}

rootProject.name = "fluffle"
include("app", "list", "utilities")
