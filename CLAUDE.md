# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## What This Is

**Fluffle** is the shared ops repo for multiple orgs (Mímis Gildi, Gervi Héra Vitr, and others).
It is the canonical source for reusable GitHub Actions, workflow templates, runner infrastructure,
and project scaffolding templates.

Child repos (riddle-me-this, sindri-labs, etc.) consume actions and workflows from here.
When actions drift in child repos, they get corrected here first, then ported back.

## Repository Structure

| Directory                     | Purpose                                                   |
|-------------------------------|-----------------------------------------------------------|
| `.github/actions/`            | 13 shared composite GitHub Actions -- the primary product |
| `.github/workflows/`          | 12 shared workflow templates                              |
| `templates-sdk/`              | SDKMAN-based project scaffolding                          |
| `templates-gradle/`           | Gradle project template                                   |
| `templates-scala/`            | Scala/sbt project template                                |
| `templates-miniforge/`        | Miniforge/conda project template                          |
| `app/`, `list/`, `utilities/` | Gradle subprojects (shared libraries)                     |
| `build-logic/`                | Gradle convention plugins                                 |

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

## Trunk-Based Development

Same as all Mímis Gildi repos: linear history, feature branches merge to `main`.

## Key Actions

| Action                                   | Purpose                                        |
|------------------------------------------|------------------------------------------------|
| `introspect-runner`                      | Runner environment validation and provisioning |
| `detect-runner-type`                     | Identify self-hosted vs GitHub-hosted          |
| `feature-fail-fast`                      | Branch guard for workflow conditions           |
| `extract-component-version-and-tag`      | Semantic versioning from gradle.properties     |
| `create-annotated-git-tag-if-not-exists` | Idempotent tag creation                        |
| `commit-and-push-files`                  | Automated commit for CI-generated changes      |
| `check-pr-labels` / `check-issue-labels` | Label-based workflow gating                    |
| `release-notes-*`                        | Release notes generation pipeline              |
| `verify-release-notes-file-present`      | Release notes guard                            |
