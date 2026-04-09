# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
