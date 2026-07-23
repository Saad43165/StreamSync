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
    project.evaluationDependsOn(":app")
}

subprojects {
    fun configureNamespace() {
        val manifestFile = file("src/main/AndroidManifest.xml")
        var originalPackage: String? = null
        
        if (manifestFile.exists()) {
            try {
                var content = manifestFile.readText()
                val match = Regex("""package="([^"]*)"""").find(content)
                if (match != null) {
                    originalPackage = match.groupValues[1]
                }
                if (content.contains("package=")) {
                    content = content.replace(Regex("""package="[^"]*""""), "")
                    manifestFile.writeText(content)
                }
            } catch (e: Exception) {
                // Ignore
            }
        }

        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val ns = getNamespace.invoke(android)
                if (ns == null || ns.toString().isEmpty()) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    // Fallback to project name if we couldn't parse it from manifest
                    val targetNs = originalPackage ?: if (name.contains("inappwebview")) {
                        "com.pichillilorenzo.flutter_inappwebview"
                    } else {
                        "com.streamsync.app." + name.replace(":", "").replace("-", "")
                    }
                    setNamespace.invoke(android, targetNs)
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    if (state.executed) {
        configureNamespace()
    } else {
        afterEvaluate {
            configureNamespace()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
