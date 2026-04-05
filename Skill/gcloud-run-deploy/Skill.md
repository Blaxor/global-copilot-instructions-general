---
name: gcloud-run-deploy
description: "Use when deploying to Google Cloud Run with gcloud run deploy, especially when you need to verify gcloud login, resolve project and region defaults, and run a portable deployment command from programmer-provided specifications."
---

# GCloud Run Deploy Skill

## Goal
Deploy a service to Google Cloud Run with `gcloud run deploy`, after verifying that the Google Cloud CLI is installed, the user is authenticated, and the deployment inputs are complete.

## When to use this skill
Use this skill whenever a user wants to deploy an application or container to Google Cloud Run with `gcloud run deploy`.

## Required behavior
1. Confirm the deployment target is Cloud Run and the deployment should use `gcloud run deploy`.
2. Gather or confirm the programmer's deployment specification before running anything.
3. Require these minimum inputs unless they are already configured in `gcloud`:
   - Cloud Run service name
   - Google Cloud project ID, or a configured default project
   - Cloud Run region, or a configured default `run/region` or `compute/region`
   - Exactly one deployment target: `--image` or `--source`
4. Support additional deployment flags from the programmer's specification without hardcoding repo-specific defaults.
5. Check whether `gcloud` is installed before trying to deploy.
6. Check whether the user is already logged in with an active `gcloud` account.
7. If no active account exists:
   - Prefer asking the user before starting interactive login.
   - If the user explicitly wants the skill to proceed, run `gcloud auth login`.
   - For CI or non-interactive workflows, prefer service-account authentication over user login.
8. Resolve project and region from explicit parameters first, then from `gcloud` config defaults.
9. Fail clearly when required deployment data is still missing instead of guessing.
10. Run the deployment command with the exact programmer-specified flags after validation succeeds.
11. Echo the active account, project, region, service name, and deployment target before invoking `gcloud run deploy`.
12. Return the `gcloud` exit code.
13. Default Cloud Run minimum instances to `0` unless the programmer explicitly overrides it.
14. Reject conflicting deploy flags when a dedicated helper parameter already exists for that value.

## Helper implementation
Use the helper script in this folder:

- `invoke-gcloud-run-deploy.ps1`

## Suggested workflow
1. Ask the programmer for the Cloud Run deployment specification if it is not already available.
2. Confirm whether the deploy uses source-based deployment or a prebuilt container image.
3. Run the helper with explicit values for service, project, region, and deployment target.
4. Pass through any extra Cloud Run flags exactly as requested by using `-DeployArgs`.
5. If the helper reports that no active `gcloud` account is configured, either:
   - ask for confirmation and rerun with `-LoginIfNeeded`,
   - rerun with `-ServiceAccountKeyFile` for non-interactive authentication, or
   - stop and tell the programmer to authenticate manually.

## Suggested usage
- `./invoke-gcloud-run-deploy.ps1 -Service my-service -Project my-project -Region us-central1 -Image us-central1-docker.pkg.dev/my-project/apps/my-image:latest`
- `./invoke-gcloud-run-deploy.ps1 -Service my-service -Region europe-west1 -Source . -DeployArgs @('--allow-unauthenticated', '--memory', '512Mi', '--set-env-vars', 'ASPNETCORE_ENVIRONMENT=Production')`
- `./invoke-gcloud-run-deploy.ps1 -Service my-service -Project my-project -Region us-central1 -Image gcr.io/my-project/my-image:2026-04-04 -LoginIfNeeded -Quiet -DeployArgs @('--min-instances', '1', '--max-instances', '3')`
- `./invoke-gcloud-run-deploy.ps1 -Service my-service -Project my-project -Region us-central1 -Source . -ServiceAccountKeyFile C:\keys\deploy-sa.json`

## Notes
- This skill is intentionally portable: it does not assume a fixed repository layout, build pipeline, registry, or region.
- Prefer explicit parameters in automation even when `gcloud` defaults are configured, because that reduces machine-specific behavior.
- The helper defaults to `--min-instances 0`; pass `--min-instances` in `-DeployArgs` only when you intentionally want a different value.
- Do not repeat `--project`, `--region`, `--platform`, `--image`, or `--source` in `-DeployArgs`; the helper treats those as dedicated inputs.
- Use `--source` only when the current repository contains the intended deployable source tree.
- Use `--image` when a separate build pipeline already produced the container image.
- Service-account key activation is supported directly by the helper for non-interactive deployments.