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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
subprojects {
    project.plugins.forEach { plugin ->
        if (plugin.javaClass.name.startsWith("com.android.build.gradle")) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                // We use reflection-style access to bypass strict Kotlin typing
                val namespaceField = android.javaClass.getMethod("getNamespace")
                if (namespaceField.invoke(android) == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, project.group.toString().ifEmpty { "com.foxhound.fix" })
                }
            }
        }
    }
}