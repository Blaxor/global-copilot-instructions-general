# global-copilot-instructions-general

This repository contains general GitHub Copilot instructions that can be used across projects.

## Files

- **[global-copilot-instructions.md](./global-copilot-instructions.md)** - General Copilot instructions for code quality, best practices, documentation, testing, security, and more.
- **[Skill/mvn-java-selector/Skill.md](./Skill/mvn-java-selector/Skill.md)** - Reusable skill for running Maven with a Java installation selected from `C:\Program Files\Java` based on the Java version declared in `pom.xml`.
- **[Skill/mvn-java-selector/run-mvn-with-java-from-pom.ps1](./Skill/mvn-java-selector/run-mvn-with-java-from-pom.ps1)** - PowerShell helper that resolves `JAVA_HOME`, optionally creates a stable `jdk-<major>` junction, and runs Maven.
- **[Skill/gcloud-run-deploy/Skill.md](./Skill/gcloud-run-deploy/Skill.md)** - Reusable skill for validating `gcloud` authentication and running portable `gcloud run deploy` commands from explicit deployment specifications.
- **[Skill/gcloud-run-deploy/invoke-gcloud-run-deploy.ps1](./Skill/gcloud-run-deploy/invoke-gcloud-run-deploy.ps1)** - PowerShell helper that checks the active `gcloud` account, resolves project and region defaults, and invokes `gcloud run deploy`.

## Usage

You can use these instructions to guide GitHub Copilot in generating better code suggestions. The instructions cover:

- Code quality and maintainability
- Best practices for various programming languages
- Documentation standards
- Testing approaches
- Security considerations
- Performance guidelines

Feel free to update the instructions as needed to match your team's preferences and project requirements.

## Skills

The `Skill` folder contains reusable GitHub Copilot skills and related helpers. The Maven Java selector skill is intended for Windows-based Maven projects that must always run with the Java version required by `pom.xml`. The Cloud Run deployment skill is intended for portable, parameter-driven `gcloud run deploy` workflows that should validate authentication before deployment.