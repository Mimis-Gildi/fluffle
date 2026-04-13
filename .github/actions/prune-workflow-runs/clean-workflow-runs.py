#!/usr/bin/env python3
"""Prune workflow runs. Designed for incremental local testing."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from typing import Callable, Final


class Classification(Enum):
    NONE = ""
    KEEP = "Keep"
    DISCARD = "Discard"


class DeletionResult(Enum):
    NONE = ""
    MUTED = "Muted"
    DELETED = "Deleted"
    FAILED = "Failed"

QUERY_LIMIT_S: Final[str] = "1000"
TERMINAL_RUN_STATUSES: Final[set[str]] = {"completed"}
DEFAULT_STALE_MINUTES: Final[int] = int(os.environ.get("STALE_MINUTES", "11"))
DEFAULT_KEEP_LAST_ON_MAIN: Final[int] = int(os.environ.get("KEEP_LAST", "2"))
DRY_RUN: Final[bool] = os.environ.get("DRY_RUN", "true").lower() in ("true", "1", "yes")


# Data model

@dataclass(slots=True)
class WorkflowRun:
    """A single workflow run with classification metadata. All fields typed, no stringly-typed access."""
    database_id: int
    workflow_name: str
    created_at: str
    head_branch: str
    event: str
    status: str
    kept: Classification = Classification.NONE
    reason: str = ""
    deleted: DeletionResult = DeletionResult.NONE
    delete_error: str = ""

    @property
    def is_classified(self) -> bool:
        return self.kept != Classification.NONE

    @property
    def is_kept(self) -> bool:
        return self.kept == Classification.KEEP

    @property
    def is_discarded(self) -> bool:
        return self.kept == Classification.DISCARD

    @property
    def is_terminal(self) -> bool:
        return self.status in TERMINAL_RUN_STATUSES

    @staticmethod
    def from_gh_json(raw_run: dict) -> WorkflowRun:
        """Construct from gh run list JSON output."""
        return WorkflowRun(
            database_id=raw_run["databaseId"],
            workflow_name=raw_run["workflowName"],
            created_at=raw_run["createdAt"],
            head_branch=raw_run["headBranch"],
            event=raw_run["event"],
            status=raw_run.get("status", "unknown"),
        )

    def classify(self, kept: Classification, reason: str) -> None:
        """Set classification. Only allowed once -- raises if already classified or if NONE is passed."""
        if kept == Classification.NONE:
            raise ValueError(f"Run {self.database_id}: cannot classify as NONE")
        if self.is_classified:
            raise ValueError(f"Run {self.database_id} already classified as '{self.kept.value}' ({self.reason}), cannot reclassify as '{kept.value}' ({reason})")
        self.kept = kept
        self.reason = reason

    def keep(self, reason: str) -> None:
        self.classify(Classification.KEEP, reason)

    def discard(self, reason: str) -> None:
        self.classify(Classification.DISCARD, reason)


# Supporting functions

def parse_run_timestamp(iso_timestamp_s: str) -> datetime:
    """Parse GitHub's ISO 8601 timestamp into a timezone-aware datetime."""
    return datetime.fromisoformat(iso_timestamp_s.replace("Z", "+00:00"))


# Pipeline

class RunPipeline:
    """Chainable pipeline for workflow run pruning. Every method returns `self`."""

    def __init__(self, branch: str, runs: list[WorkflowRun]) -> None:
        self.branch: str = branch
        self.runs: list[WorkflowRun] = runs

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

        raw_runs = json.loads(gh_result.stdout)
        self.runs = [WorkflowRun.from_gh_json(raw_run) for raw_run in raw_runs]
        print(f"Fetched {len(self.runs)} runs.")
        return self

    def newest_first(self) -> RunPipeline:
        """Sort runs newest-first by createdAt. Explicit because gh run list order is undocumented."""
        self.runs.sort(key=lambda run: run.created_at, reverse=True)
        return self

    def protect_in_progress(self) -> RunPipeline:
        """Mark non-terminal runs as kept. Never delete a run that's still executing."""
        for run in self.runs:
            if run.is_classified:
                continue
            if not run.is_terminal:
                run.keep(f"in progress ({run.status}), {run.head_branch}")
        return self

    def keep_latest_on_main(self, keep_last_on_main: int = DEFAULT_KEEP_LAST_ON_MAIN) -> RunPipeline:
        """On main: mark the last N runs per workflow as kept, rest as overflow. No-op on feature branches."""
        if self.branch != "main":
            return self

        main_runs_by_workflow: dict[str, list[WorkflowRun]] = {}
        for run in self.runs:
            if run.head_branch == "main":
                main_runs_by_workflow.setdefault(run.workflow_name, []).append(run)

        for workflow_name, workflow_runs in main_runs_by_workflow.items():
            for position, run in enumerate(workflow_runs):
                if run.is_classified:
                    continue
                if position < keep_last_on_main:
                    run.keep(f"main, #{position + 1} of {workflow_name}")
                else:
                    run.discard(f"main overflow, #{position + 1} of {workflow_name}")

        return self

    def keep_within_grace_window(self, stale_minutes: int = DEFAULT_STALE_MINUTES) -> RunPipeline:
        """Mark unclassified runs: kept if within the grace window, deletable if stale."""
        now = datetime.now(timezone.utc)
        for run in self.runs:
            if run.is_classified:
                continue
            run_age_minutes = (now - parse_run_timestamp(run.created_at)).total_seconds() / 60
            if run_age_minutes < stale_minutes:
                run.keep(f"grace, {run_age_minutes:.0f}m old, {run.head_branch}")
            else:
                run.discard(f"stale, {run_age_minutes:.0f}m old, {run.head_branch}")
        return self

    @staticmethod
    def _delete_one_run(run: WorkflowRun) -> WorkflowRun:
        """Delete a single run via gh CLI. Annotates with the result. No printing."""
        run_id_s = str(run.database_id)
        if DRY_RUN:
            run.deleted = DeletionResult.MUTED
        else:
            delete_result = subprocess.run(
                ["gh", "run", "delete", run_id_s],
                capture_output=True, text=True
            )
            if delete_result.returncode == 0:
                run.deleted = DeletionResult.DELETED
            else:
                run.deleted = DeletionResult.FAILED
                run.delete_error = delete_result.stderr.strip()
        return run

    def remove_discarded(self) -> RunPipeline:
        """Fan out deletion of all Discard-marked runs, collect results. Respects module-level DRY_RUN."""
        discarded_runs = [run for run in self.runs if run.is_discarded]
        if not discarded_runs:
            print("Nothing to remove.")
            return self

        with ThreadPoolExecutor() as executor:
            list(executor.map(self._delete_one_run, discarded_runs))

        for run in discarded_runs:
            error_text = f"  {run.delete_error}" if run.delete_error else ""
            print(f"  gh run delete {run.database_id}  # {run.deleted.value.lower()}: {run.reason}{error_text}")

        return self

    def report(self, actor: Callable[[list[WorkflowRun]], None]) -> RunPipeline:
        """Pass the run collection to an actor function (print, summarize, etc.)"""
        actor(self.runs)
        return self


# Actors

def write_summary(workflow_runs: list[WorkflowRun]) -> None:
    """Write kept/discarded Markdown tables. Writes to GITHUB_STEP_SUMMARY or stdout."""
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    out = open(summary_path, "a") if summary_path else sys.stdout

    kept_runs = [run for run in workflow_runs if run.is_kept]
    discarded_runs = [run for run in workflow_runs if run.is_discarded]

    print(f"\n### Kept ({len(kept_runs)})\n", file=out)
    print("| Run ID | Workflow | Branch | Status | Created | Reason |", file=out)
    print("|--------|----------|--------|--------|---------|--------|", file=out)
    for run in kept_runs:
        print(f"| {run.database_id} | {run.workflow_name} | {run.head_branch} | {run.status} | {run.created_at} | {run.reason} |", file=out)

    print(f"\n### Discarded ({len(discarded_runs)})\n", file=out)
    print("| Run ID | Workflow | Branch | Status | Created | Reason | Result |", file=out)
    print("|--------|----------|--------|--------|---------|--------|--------|", file=out)
    for run in discarded_runs:
        deleted_display = run.deleted.value if run.deleted != DeletionResult.NONE else "Pending"
        print(f"| {run.database_id} | {run.workflow_name} | {run.head_branch} | {run.status} | {run.created_at} | {run.reason} | {deleted_display} |", file=out)

    dry_run_notice_s = " (DRY RUN)" if DRY_RUN else ""
    print(f"\n**Total:** {len(workflow_runs)} | **Kept:** {len(kept_runs)} | **Discarded:** {len(discarded_runs)}{dry_run_notice_s}", file=out)

    if out is not sys.stdout:
        out.close()


# Main

if __name__ == "__main__":
    RunPipeline.on_current_branch() \
        .fetch_all_runs() \
        .newest_first() \
        .protect_in_progress() \
        .keep_latest_on_main() \
        .keep_within_grace_window() \
        .remove_discarded() \
        .report(write_summary)
