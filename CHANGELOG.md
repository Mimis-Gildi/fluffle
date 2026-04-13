# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [5.0.3]

- Release activities for testing workflow bug fixes.

## [5.0.2]

### Added
- Run pruner `protect_in_progress()` pipeline step -- runs with non-terminal status are protected from deletion regardless of age or keep-last settings
- `pyproject.toml` with `requires-python = ">=3.10"` -- IntelliJ picks up conda `ml` environment on project import

### Fixed
- Git credential failure on Debian hosts (git 2.35.2+ tightened `includeIf.gitdir` path matching; CVE-2022-24765) -- `incrementer.yml` and `releaser.yml` now set the remote URL explicitly with the token via `git remote set-url origin`

### Changed
- Prune workflow `dry-run` default flipped to `false` -- pruning is live by default
- Prune workflow `stale-minutes` defaults tuned per trigger: `3` for dispatch, `5` for call, `7` fallback for push

## [5.0.0]

### Added
- Workflow run pruner rewritten in Python with functional chainable pipeline (`RunPipeline`)
- Workflow cache pruner rewritten in Python with matching pipeline (`CachePipeline`)
- Both pruners: parallel deletion via `ThreadPoolExecutor`, sequential reporting after collection
- Both pruners: detailed Markdown step summaries (kept/discarded tables with reasons)
- Both pruners: `DRY_RUN` mode controlled via workflow inputs, defaults safe for testing
- Cache pruner: `MAX(created_at, last_accessed_at)` effective timestamp for robust age calculation
- Cache pruner: key prefix parsing to group caches by workflow identity, not per-commit SHA
- Team norms (`TEAM_NORMS.md`) wired into `CLAUDE.md` via `@` import -- loaded every session
- Shared workflow parameters (`keep-last`, `stale-minutes`, `dry-run`) across run and cache pruners
- Workflow inputs for `workflow_dispatch` and `workflow_call` with sensible defaults

### Changed
- Prune design: on main, keep last N per workflow/key, delete overflow; on feature branches, grace window only
- Cache pruner uses `gh api` (REST) instead of `gh-actions-cache` extension -- no extension install step needed
- Run pruner sort is explicit (`createdAt` descending) -- `gh run list` sort order is undocumented

### Removed
- Shell-based run pruner (`clean-workflow-runs.sh`)
- Shell-based cache pruner (`clean-workflow-run-caches.sh`)
- `gh-actions-cache` extension dependency
- `max-parallel` action input (sequential deletion replaced by ThreadPoolExecutor)
- `Trunk-Based Development` section from `CLAUDE.md` (covered by `TEAM_NORMS.md` Rule 3)

## [4.0.0]

### Added
- Workflow templates for org-wide adoption (greeting, prune, labeler, introspector, stales, pages, incrementer)
- Runner introspector decomposed into detect/upgrade actions (sdkman, conda, ruby, java, sdk-candidates)
- Matrix-driven SDK candidate detection and upgrade
- Temporal version incrementer with major/minor/patch on create/PR/push
- Jekyll site scaffold
- Extract changelog section action (from total-recall)

### Changed
- Runner introspector restructured into parallel jobs with dependency graph
- Pages build/deploy workflows cleaned and externalized
- Stales workflow upgraded to actions/stale v10.2.0 with delete-branch
- All reusable workflows reference fluffle actions via remote path

### Removed
- Monolithic introspect-runner action (replaced by decomposed detect/upgrade actions)
- Generated release notes pipeline (replaced by Keep a Changelog)
