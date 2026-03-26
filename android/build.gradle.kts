buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

gradle.projectsEvaluated {
    subprojects {
        extensions.findByName("android")?.let { androidExt ->
            if (androidExt is com.android.build.gradle.BaseExtension) {
                if (androidExt.namespace.isNullOrEmpty()) {
                    androidExt.namespace = project.group.toString().ifEmpty {
                        "com.${project.name.replace(Regex("[^a-zA-Z0-9]"), "")}"
                    }
                }
            }
        }
    }
}

subprojects {
    // Changed: set namespace as soon as Android library plugins are applied (AGP 8+ requirement).
    pluginManager.withPlugin("com.android.library") {
        extensions.findByName("android")?.let { androidExt ->
            if (androidExt is com.android.build.gradle.BaseExtension) {
                if (androidExt.namespace.isNullOrEmpty()) {
                    androidExt.namespace = project.group.toString().ifEmpty {
                        "com.${project.name.replace(Regex("[^a-zA-Z0-9]"), "")}"
                    }
                }
            }
        }
    }
}