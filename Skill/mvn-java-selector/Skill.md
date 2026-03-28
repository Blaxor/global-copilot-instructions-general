# Maven Java Selector Skill

## Goal
Always run Maven with a Java installation resolved from `C:\Program Files\Java`, matching the Java version required by the active `pom.xml`.

## When to use this skill
Use this skill whenever a repository contains a `pom.xml` and Maven must be executed.

## Required behavior
1. Read `pom.xml` before running Maven.
2. Resolve the requested Java version using this precedence:
   - `properties.maven.compiler.release`
   - `properties.java.version`
   - `properties.maven.compiler.target`
   - `build.plugins.plugin[artifactId=maven-compiler-plugin].configuration.release`
   - `build.plugins.plugin[artifactId=maven-compiler-plugin].configuration.target`
   - `build.plugins.plugin[artifactId=maven-compiler-plugin].configuration.source`
3. Normalize the version to a Java major version.
   - `1.8` -> `8`
   - `17.0.10` -> `17`
   - `21` -> `21`
4. Search only under `C:\Program Files\Java`.
5. Prefer a JDK over a JRE.
6. Prefer the stable alias path `C:\Program Files\Java\jdk-<major>` when it exists.
7. If `C:\Program Files\Java\jdk-<major>` does not exist but a matching Java installation exists under the same base path, create a junction at that stable alias and use it.
8. If `C:\Program Files\Java` does not exist, create the base folder before continuing.
9. Set `JAVA_HOME` to the resolved path and prepend `%JAVA_HOME%\\bin` to `PATH` for the Maven command.
10. Prefer `mvnw.cmd` when the project provides a Maven wrapper. Otherwise use `mvn.cmd`.
11. Never rely on whichever `java.exe` is already first on `PATH`.
12. If no matching Java version exists, stop with a clear message that says which Java version must be installed under `C:\Program Files\Java`.

## Helper implementation
Use the helper script in this folder:

- `run-mvn-with-java-from-pom.ps1`

## Suggested usage
- `./run-mvn-with-java-from-pom.ps1 clean verify`
- `./run-mvn-with-java-from-pom.ps1 -PomPath ./module-a/pom.xml test`
- `./run-mvn-with-java-from-pom.ps1 -CreateStableLink $true -PomPath ./pom.xml -DskipTests package`

## Notes
- Creating directories or junctions below `C:\Program Files` can require elevated permissions.
- If the Java version is declared indirectly with a property reference like `${java.version}`, resolve the property before choosing Java.
- If the version cannot be determined from `pom.xml`, fail clearly instead of guessing.
