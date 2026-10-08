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
}

subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            
            // 1. Fix the Namespace Error (Safe to apply globally)
            try {
                val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                
                if (getNamespace.invoke(androidExt) == null) {
                    setNamespace.invoke(androidExt, project.group.toString())
                }
            } catch (e: Exception) {
                // Ignore if methods are not found 
            }

            // 2. Fix the SDK version ONLY for legacy plugins!
            if (project.name == "flutter_app_badger" || project.name == "add_2_calendar") {
                try {
                    val compileSdkVersion = androidExt.javaClass.getMethod("compileSdkVersion", Int::class.java)
                    compileSdkVersion.invoke(androidExt, 34)
                } catch (e: Exception) {
                    try {
                        val setCompileSdk = androidExt.javaClass.getMethod("setCompileSdk", Int::class.java)
                        setCompileSdk.invoke(androidExt, 34)
                    } catch (e2: Exception) {
                        // Ignore
                    }
                }
            }
            
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}