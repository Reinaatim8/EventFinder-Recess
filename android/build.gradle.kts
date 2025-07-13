buildscript {
    val kotlinVersion = "2.1.0"  // Change from 2.0.20 to 2.1.0
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.7.3")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.configurations.all {
        resolutionStrategy {
            eachDependency {
                if (requested.group == "org.jetbrains.kotlin") {
                    useVersion("2.1.0")  // Change from 2.0.20 to 2.1.0
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}