# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## MANDATORY: Team Norms

@TEAM_NORMS.md

These rules are non-negotiable. They are loaded automatically every session.

## What This Is

**Fluffle** is the shared ops repo for multiple orgs (Mímis Gildi, Gervi Héra Vitr, and others).
It is the canonical source for reusable GitHub Actions, workflow templates, runner infrastructure,
and project scaffolding templates.

Child repos (riddle-me-this, sindri-labs, etc.) consume actions and workflows from here.
When actions drift in child repos, they get corrected here first, then ported back.

## Repository Structure

| Directory                     | Purpose                                                                 |
|-------------------------------|-------------------------------------------------------------------------|
| `.github/actions/`            | Shared composite GitHub Actions (runner detect/upgrade, prune, welcome) |
| `.github/workflows/`          | 10 shared workflow templates                                            |
| `templates-sdk/`              | SDKMAN-based project scaffolding                                        |
| `templates-gradle/`           | Gradle project template                                                 |
| `templates-scala/`            | Scala/sbt project template                                              |
| `templates-miniforge/`        | Miniforge/conda project template                                        |
| `app/`, `list/`, `utilities/` | Gradle subprojects (shared libraries)                                   |
| `build-logic/`                | Gradle convention plugins                                               |

## Philosophy

**Leave it better than you found it.** Every project that touches these actions should improve them.
Fixes go here first, then propagate to consumers.

**The runner canary is a provisioner, not just a validator.**
The `introspect-runner` action validates the self-hosted runner environment.
When the runner is behind the declared threshold, the action should upgrade it and fail
(signaling a re-run). When the runner is ahead, that's fine -- thresholds are floors, not pins.

**`.sdkmanrc` is project-scoped.** It governs local dev and project builds.
The runner's toolchain is governed by the introspect action's version inputs.
These are separate contracts.

## Build

```zsh
gradle clean build test
```

## Key Actions

| Action                        | Purpose                                          |
|-------------------------------|--------------------------------------------------|
| `runner-detect-*`             | Detect sdkman, java, conda, ruby, sdk-candidates |
| `runner-upgrade-*`            | Upgrade sdkman, java, conda, sdk-candidates      |
| `prune-workflow-runs`         | Prune old workflow runs                          |
| `prune-workflow-caches`       | Prune stale GitHub Actions caches                |
| `welcome-first-contributor`   | Greet first-time issue/PR authors                |
