pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "supercamera-android-demo"
include(":app")
include(":supercamera")
project(":supercamera").projectDir = file("../../android/supercamera")
include(":supercamera-ui")
project(":supercamera-ui").projectDir = file("../../android/supercamera-ui")
