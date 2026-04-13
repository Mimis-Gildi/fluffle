#!/usr/bin/env python3
"""Prune workflow runs. Designed for incremental local testing."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from typing import Callable, Final

LOG_PAGE_SIZE: Final[int] = 25
QUERY_LIMIT_S: Final[str] = "1000"
DEFAULT_STALE_MINUTES: Final[int] = int(os.environ.get("STALE_MINUTES", "11"))
DEFAULT_KEEP_LAST_ON_MAIN: Final[int] = int(os.environ.get("KEEP_LAST", "2"))
DRY_RUN: Final[bool] = os.environ.get("DRY_RUN", "true").lower() in ("true", "1", "yes")


# Supporting functions

def parse_run_timestamp(iso_timestamp_s: str) -> datetime:
    """Parse GitHub's ISO 8601 timestamp into a timezone-aware datetime."""
    return datetime.fromisoformat(iso_timestamp_s.replace("Z", "+00:00"))


# Pipeline

class RunPipeline:
    """Chainable pipeline for workflow run pruning. Every method returns `self`."""

    def __init__(self, branch: str, runs: list[dict]) -> None:
        self.branch: str = branch
        self.runs: list[dict] = runs

    @classmethod
    def on_current_branch(cls) -> RunPipeline:
        """Detect the current branch from environment or git."""
        detected_branch = os.environ.get("BRANCH") or subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True
        ).stdout.strip()
        print(f"Branch: {detected_branch}")
        return cls(branch=detected_branch, runs=[])

    def fetch_all_runs(self) -> RunPipeline:
        """Fetch runs from GitHub. Filtered by branch on feature branches, unfiltered on main."""
        workflow_runs_query_fields = "databaseId,workflowName,createdAt,headBranch,event,status"
        workflow_runs_command = ["gh", "run", "list", "--json", workflow_runs_query_fields, "--limit", QUERY_LIMIT_S]
        if self.branch != "main":
            workflow_runs_command.extend(["--branch", self.branch])

        gh_result = subprocess.run(workflow_runs_command, capture_output=True, text=True)
        if gh_result.returncode != 0:
            print(f"::error title=Fetch Failed::{gh_result.stderr.strip()}", file=sys.stderr)
            sys.exit(1)

        self.runs = json.loads(gh_result.stdout)
        print(f"Fetched {len(self.runs)} runs.")
        return self

    def newest_first(self) -> RunPipeline:
        """Sort runs newest-first by createdAt. Explicit because gh run list order is undocumented."""
        self.runs.sort(key=lambda row: row.get("createdAt", ""), reverse=True)
        return self

    def keep_latest_on_main(self, keep_last_on_main: int = DEFAULT_KEEP_LAST_ON_MAIN) -> RunPipeline:
        """On main: mark the last N runs per workflow as kept, rest as overflow. No-op on feature branches."""
        if self.branch != "main":
            return self

        main_runs_by_workflow: dict[str, list[dict]] = {}
        for run in self.runs:
            if run["headBranch"] == "main":
                main_runs_by_workflow.setdefault(run["workflowName"], []).append(run)

        for workflow_name, workflow_runs in main_runs_by_workflow.items():
            for position, run in enumerate(workflow_runs):
                if position < keep_last_on_main:
                    run["kept"] = "Keep"
                    run["reason"] = f"main, #{position + 1} of {workflow_name}"
                else:
                    run["kept"] = "Discard"
                    run["reason"] = f"main overflow, #{position + 1} of {workflow_name}"

        return self

    def keep_within_grace_window(self, stale_minutes: int = DEFAULT_STALE_MINUTES) -> RunPipeline:
        """Mark unclassified runs: kept if within the grace window, deletable if stale."""
        now = datetime.now(timezone.utc)
        for run in self.runs:
            if "kept" in run:
                continue
            run_age_minutes = (now - parse_run_timestamp(run["createdAt"])).total_seconds() / 60
            if run_age_minutes < stale_minutes:
                run["kept"] = "Keep"
                run["reason"] = f"grace, {run_age_minutes:.0f}m old, {run['headBranch']}"
            else:
                run["kept"] = "Discard"
                run["reason"] = f"stale, {run_age_minutes:.0f}m old, {run['headBranch']}"
        return self

    def remove_discarded(self) -> RunPipeline:
        """Delete runs marked as Discard. Respects module-level DRY_RUN."""
        discarded_runs = [run for run in self.runs if run.get("kept") == "Discard"]
        if not discarded_runs:
            print("Nothing to remove.")
            return self

        for run in discarded_runs:
            run_id_s = str(run["databaseId"])
            delete_command_s = f"gh run delete {run_id_s}"
            if DRY_RUN:
                run["deleted"] = "Muted"
                print(f"  {delete_command_s}  # muted: {run['reason']}")
            else:
                delete_result = subprocess.run(
                    ["gh", "run", "delete", run_id_s],
                    capture_output=True, text=True
                )
                if delete_result.returncode == 0:
                    run["deleted"] = "Deleted"
                    print(f"  {delete_command_s}  # done: {run['reason']}")
                else:
                    run["deleted"] = "Failed"
                    print(f"  {delete_command_s}  # FAILED: {run['reason']}  {delete_result.stderr.strip()}")

        return self

    def report(self, actor: Callable[[list[dict]], None]) -> RunPipeline:
        """Pass the run collection to an actor function (print, summarize, etc.)"""
        actor(self.runs)
        return self


# Actors

def write_summary(workflow_runs: list[dict]) -> None:
    """Write kept/discarded Markdown tables. Writes to GITHUB_STEP_SUMMARY or stdout."""
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    out = open(summary_path, "a") if summary_path else sys.stdout

    kept_runs = [run for run in workflow_runs if run.get("kept") == "Keep"]
    discarded_runs = [run for run in workflow_runs if run.get("kept") == "Discard"]

    print(f"\n### Kept ({len(kept_runs)})\n", file=out)
    print("| Run ID | Workflow | Branch | Created | Reason |", file=out)
    print("|--------|----------|--------|---------|--------|", file=out)
    for run in kept_runs:
        print(f"| {run['databaseId']} | {run['workflowName']} | {run['headBranch']} | {run['createdAt']} | {run['reason']} |", file=out)

    print(f"\n### Discarded ({len(discarded_runs)})\n", file=out)
    print("| Run ID | Workflow | Branch | Created | Reason | Result |", file=out)
    print("|--------|----------|--------|---------|--------|--------|", file=out)
    for run in discarded_runs:
        deleted_status = run.get("deleted", "Pending")
        print(f"| {run['databaseId']} | {run['workflowName']} | {run['headBranch']} | {run['createdAt']} | {run['reason']} | {deleted_status} |", file=out)

    dry_run_notice_s = " (DRY RUN)" if DRY_RUN else ""
    print(f"\n**Total:** {len(workflow_runs)} | **Kept:** {len(kept_runs)} | **Discarded:** {len(discarded_runs)}{dry_run_notice_s}", file=out)

    if out is not sys.stdout:
        out.close()


# Main

if __name__ == "__main__":
    RunPipeline.on_current_branch() \
        .fetch_all_runs() \
        .newest_first() \
        .keep_latest_on_main() \
        .keep_within_grace_window() \
        .remove_discarded() \
        .report(write_summary)
