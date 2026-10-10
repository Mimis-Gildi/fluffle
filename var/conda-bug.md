# Handoff: live with conda-pypi, keep it out of ml (from riddle-me-this session, 2026-10-08)

## Note to self (fluffle session)

You are woken up in fluffle to HELP fix the runner conda actions. 
The words "help" is important - you physically cannot fix anything because you only interpolate, but extrapolation is
required for any real reasoning. Vadim will fix the bug. He extrapolates but doesn't interpolate well.
That's where you come in. Everything here was established in a riddle-me-this session where the bug was discovered; 
facts marked verified were checked there, the rest is labeled. Your job:

1. Read this file whole. Then read `.github/actions/runner-upgrade-conda/`, `.github/actions/runner-detect-conda/`,
   `.github/workflows/runner-introspector.yml` before saying anything.
2. State your understanding: root cause and corrective options to Vadim.
3. Don't repeat the past SLOP mistakes you are famous for:
- Claiming something without reading it (e.g. which file Jekyll reads, what the runner has).
- Mechanical lists over cruft (`env export`, computed leaves) instead of choosing by purpose.
- Padding, adjacent topics, unsolicited options.

## Goal (Vadim's rule)

1. conda + conda core (including conda-pypi) live ONLY in the `base`.
2. `ml` holds ML-research packages ONLY, as Vadim decides.
3. PyPI-only packages get into ml through base: `conda pypi install -n ml <pkg>`.
4. Channels, `channel_priority: strict`:
   - conda-forge is hardcoded in the Miniforge package; present even with no config anywhere.
   - `defaults` is allowed and will often be present.
   - User-added channels are fine: appended at lowest priority and called out loudly in a warning.
   - The `conda-pypi` channel is a horrible bug: rip it out with vengeance.

Restate your understanding to Vadim. Speak of ANY conflicts you may see; for example, `base` moves to python 3.14 while
`ml` is at python 3.12.latest - is there a problem with `conda pypi install -n ml <pkg>` resolving against `base` while
used in `ml`?

## Verified facts

- conda hard-depends on conda-pypi since 26.5.0 (conda-forge and defaults alike):
  ≤26.3.2 none; 26.5.x ≥0.9.0; 26.7.x ≥0.10.1; 26.9.x ≥0.13.0. In `base` it is unavoidable – accept it.
- conda-pypi 0.11.0 `plugin.py` registers only:
  `conda pypi` subcommand; a post-command notice (`notify-externally-managed-future`) on install/create/env_create;
  a `.whl` extractor; a `conda doctor` health check (`external-packages`, fixer `migrate_to_conda`);
  setting `conda_pypi_pip_warning` (default true). No channel added.
  No `EXTERNALLY-MANAGED` currently exists in base or ml (Mac).
- `conda pypi install [-n ENV] [--ignore-channels] [-i INDEX_URL] PKG…`: deps available on configured conda
  channels come from conda; the rest are converted from PyPI to conda packages.
- conda-pypi 0.11.0 `convert_tree.py` keeps converted wheels in its OWN local channel at
  `platformdirs.user_data_dir("conda-pypi")` (Linux: `~/.local/share/conda-pypi`), with `noarch/repodata.json`.
  A bare `conda-pypi` in `.condarc` is something else: `https://conda.anaconda.org/conda-pypi` → HTTP 404.
- `upgrade-conda.sh` (commit 560ddbf, 2026-07-16), run after `conda activate ml`:
  ```
  conda config --append channels conda-pypi
  conda install -y conda-pypi
  ```
  This is ALL your past SLOP Vadim missed. Don't rely on implemented code as "known good" - it isn't!
  Voice your concerns to Vadim every time there's any lack of clarity on your part.

  - Line 1 adds the 404 channel to `~/.condarc`.
  - Line 2: conda-pypi depends on `conda >=26.1.0`, so it pulled the full conda core into ml
    (conda, conda-libmamba-solver, conda-rattler-solver, conda-self, conda-index, conda-lockfiles).
    Mac evidence: `CONDA_EXE=~/miniforge3/envs/ml/bin/conda`; ml history `2026-07-16 conda install -y conda-pypi pydantic pyfunctional`.
- `upgrade-conda.sh` checks no exit codes; the step's status is the last `printf`. Failures stay green.
- Mac channel priority (effective): root `.condarc` `[conda-forge]`, user `~/.condarc` `[defaults, conda-forge]`
  → `defaults` first; `channel_priority: flexible`. Conda core came from `defaults` (builds `py312hca03da5_0`).
  Don't use your local Mac environment here as "know good" - it isn't, Vadim hasn't fixed it yet. He will after the runners are fixed.

## Runner tom – canary run 102106247499, conda job (verified from logs)

Vadim collected the runner log before removing the conda-pypi channel from `~/.condarc` on `tom`: @var/runner_tom_logs_102106247499.zip

He's rerunning the job again now for your later discussion.

Meanwhile:

- Introspect: Python 3.12.14, Conda 26.9.1, Mamba 2.9.0 (detect inputs expected 3.12.13 / 26.5.3 / 2.8.1 – notice only).
- Every solve: `Channels: - conda-forge - conda-pypi`.
- `conda config --append channels conda-pypi` → `CondaError: Cannot write to condarc file … PermissionError(13)`.
  Cause: `~/.condarc` mode 444 (owner runner user, no chattr, rw mount, no systemd sandbox). Vadim made it 444;
  the conda-pypi line was still in it (last content write 2026-09-07 05:39:44).
- General-deps install: solver chose `opentelemetry-api-1.45.1 py3_none_any_0` from `conda-pypi/noarch`
  although conda-forge has `1.45.1 pyhd8ed1ab_0` → download 404 → transaction aborted;
  pydantic, fastapi, jproperties, pytest and ~40 new packages NOT installed. Job still green.
- python/libpython flip-flop every run, base and ml: `upgrade python` → python 3.12.15 + libpython 3.12.15;
  `upgrade --all` → back to python 3.12.14 + libpython 3.14.8 (cp314). Both envs end on 3.12 python with 3.14 libpython.
- Tom `~/.condarc` contained `allow_conda_downgrades: true` + channels `[conda-forge, conda-pypi]`.
- 2026-10-08: Vadim removed the conda-pypi channel on tom, re-protected `.condarc` (444), and reran canary.
  Read that rerun's conda job before changing anything.

Restate your understanding to Vadim.

## Desired-state logic (agreed)

Trigger = effective config ≠ desired (Goal rule 4).
- Check the merged config (`conda config --show channels channel_priority`), not a grep of `~/.condarc`:
  conda also reads root `.condarc`, `~/.conda/.condarc`, `~/.config/conda/condarc`, env-level `.condarc`, `$CONDARC`.
  Those need to be ripped out with vengeance if found, Vadim's design calls for `~/.condarc` ONLY.
- Desired: no `conda-pypi` channel; user channels appended at lowest priority with a warning; `channel_priority: strict`;
  no `conda*` packages in ml.
Remedy is graded by defect (suggested):
| Defect | Remedy |
|---|---|
| conda broken (`conda --version` gives no version) | Recovery policy below – blow away, reinstall |
| Config drift (channels / priority) | `conda config` only – never touch `.condarc` directly. No reinstall |
| conda core inside ml | detect hoses – Recovery policy below |
| base python on 3.12 (pinned by `install python=3.12`, unremovable) | detect hoses – Recovery policy below |
| ml healthy | upgrade: `python`, then `--all` |

## Recovery policy (Vadim's rule)

If conda is broken – `conda --version` returns no version or fails in any command execution attempt – do not repair:
1. Blow the install away completely (the whole miniforge root; on tom `~/miniforge3` is a symlink to
   `/var/actions/miniforge3-mimis-gildi` fyi). Delete `.condarc` Don't MESS with the bootstrap files (zsh)!
2. Reinstall Miniforge.
3. `conda config --set channel_priority strict` (as `var/agent/bin/conda-up` does).
4. Recreate ml: `python=3.12` pinned + MINIMAL core list chosen by purpose; the rest comes in by dependency.
   Never from an `env export` dump as stupid LLM would be tempted to do. Vadim has a draft of that command for you.
   PyPI-only packages via `conda pypi install -n ml` from base?

Unverified: installer invocation (expected `Miniforge3-$(uname)-$(uname -m).sh -b -p <root>`),
and how `conda init`/shell hooks in `zsh -l` and `conda-activate.sh` behave after reinstall.

Ask Vadim when not sure.

## Bugfix (get Vadim's ack before each)

1. `upgrade-conda.sh` (proposed, Vadim didn't review):
   - Delete both conda-pypi lines.
   - Add the desired-state checks and graded remedies above.
   - Stop `conda activate ml` for installs; target the env from base:
     `conda install -y -n ml …`, `conda upgrade -y -n ml python`, `conda upgrade -y -n ml --all`;
     keep `conda env config vars set KERAS_BACKEND=torch -n ml`.
   - Any PyPI-only package for ml: `conda pypi install -y -n ml <pkg>` from base.
   - Check exit codes; fail the job on any failed conda command. End with a verification of the desired state.
   - Optional: `conda config --set conda_pypi_pip_warning false` (writes `.condarc` via `conda config`).
   - Summary block uses `mamba info` and `python --version` – check they report what's intended without ml activated.
2. Check `runner-detect-conda/` (`detect-conda.sh`, `conda-activate.sh`) and `workflows/runner-introspector.yml`
   for anything assuming conda inside ml or a specific channel list.
3. Open for Vadim: the python/libpython flip-flop (`upgrade python` vs `upgrade --all`); `allow_conda_downgrades: true`
   on tom – keep or not.

Talk to Vadim about this proposal of mine. You and he will create an actual one. Know that `ml` is always the activated
environment default for anything running on that runner.

## Unverified – check, don't assume

- conda-pypi ≥0.13 (tom) – only 0.11 was read. Check it needs no `.condarc` channel entry for `conda pypi install`.
- How tom's solver saw a `conda-pypi/noarch` index containing `opentelemetry-api` (tom's `~/.local/share/conda-pypi`?).
- Other agents' state – only tom's logs and the Mac were examined.
- Whether strict priority re-sources packages already installed from `defaults` on `upgrade --all`.
- That `conda remove` of conda from ml succeeds (nothing else in ml depends on conda).
- What `notify_externally_managed_future` announces; a future conda-pypi may write `EXTERNALLY-MANAGED` into envs.
- Whether `conda doctor --fix` converts ml's `pypi_0` pip packages.
- `date -d '-1 hour'` in the script is GNU-only; breaks on macOS runners. Pre-existing, out of scope unless Vadim says.

This is more of my slop - you do your due diligence.

## Rules

You don't DO! You HELP.
