android {
    namespace = "com.example.event_locator_app"
    compileSdk = 34

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.event_locator_app"
        minSdk = 21
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Additional configurations for better compatibility
        multiDexEnabled = true
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        
        // Vector drawables support
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        release {
            // Signing configuration for release builds
            signingConfig = signingConfigs.getByName("debug")
            
            // Code shrinking and obfuscation
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        
        debug {
            applicationIdSuffix = ".debug"
            isDebuggable = true
        }
    }

    // Configure build features
    buildFeatures {
        buildConfig = true
    }

    // Packaging options
    packagingOptions {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    // Lint options
    lint {
        disable += "InvalidPackage"
        checkReleaseBuilds = false
    }

    // Dependency resolution strategy
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core-ktx:1.10.1")
            force("androidx.lifecycle:lifecycle-runtime-ktx:2.6.1")
        }
    }

    // Source sets (if needed)
    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }
}