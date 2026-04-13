#!/usr/bin/env python3
"""Prune workflow caches. Same functional pipeline as the run pruner."""
from __future__ import annotations

import json
import os
import re
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


DEFAULT_STALE_MINUTES: Final[int] = int(os.environ.get("STALE_MINUTES", "11"))
DEFAULT_KEEP_LAST_ON_MAIN: Final[int] = int(os.environ.get("KEEP_LAST", "2"))
DRY_RUN: Final[bool] = os.environ.get("DRY_RUN", "true").lower() in ("true", "1", "yes")


# Compiled patterns

NANOSECOND_TRUNCATION_PATTERN = re.compile(r'(\.\d{6})\d+')
CACHE_KEY_PATTERN = re.compile(r'^(.+)-([0-9a-f]{40})$')


# Data model

@dataclass(slots=True)
class WorkflowCache:
    """A single workflow cache with classification metadata. All fields typed."""
    cache_id: int
    key: str
    key_prefix: str
    ref: str
    version: str
    created_at: str
    last_accessed_at: str
    size_in_bytes: int
    effective_timestamp: datetime
    repository: str
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
    def size_mb(self) -> float:
        return self.size_in_bytes / (1024 * 1024)

    @staticmethod
    def _parse_timestamp(iso_timestamp_s: str) -> datetime:
        """Parse GitHub's ISO 8601 timestamp. Truncates nanosecond precision to microseconds."""
        truncated_timestamp_s = NANOSECOND_TRUNCATION_PATTERN.sub(r'\1', iso_timestamp_s)
        return datetime.fromisoformat(truncated_timestamp_s.replace("Z", "+00:00"))

    @staticmethod
    def _parse_key_prefix(full_cache_key: str) -> str:
        """Extract stable prefix from cache key, stripping commit SHA.
        Fails hard on unexpected format -- we want to know."""
        match = CACHE_KEY_PATTERN.match(full_cache_key)
        if not match:
            print(f"::error title=Unexpected Cache Key::Cannot parse cache key: {full_cache_key}", file=sys.stderr)
            sys.exit(1)
        return match.group(1)

    @staticmethod
    def from_gh_json(raw_cache: dict, repository: str) -> WorkflowCache:
        """Construct from GitHub REST API JSON output."""
        created_at_s = raw_cache.get("created_at", "1970-01-01T00:00:00Z")
        last_accessed_at_s = raw_cache.get("last_accessed_at", "1970-01-01T00:00:00Z")
        created = WorkflowCache._parse_timestamp(created_at_s)
        accessed = WorkflowCache._parse_timestamp(last_accessed_at_s)
        full_key = raw_cache.get("key", "")
        return WorkflowCache(
            cache_id=raw_cache["id"],
            key=full_key,
            key_prefix=WorkflowCache._parse_key_prefix(full_key),
            ref=raw_cache.get("ref", ""),
            version=raw_cache.get("version", ""),
            created_at=created_at_s,
            last_accessed_at=last_accessed_at_s,
            size_in_bytes=raw_cache.get("size_in_bytes", 0),
            effective_timestamp=max(created, accessed),
            repository=repository,
        )

    def classify(self, kept: Classification, reason: str) -> None:
        """Set classification. Only allowed once -- raises if already classified or if NONE is passed."""
        if kept == Classification.NONE:
            raise ValueError(f"Cache {self.cache_id}: cannot classify as NONE")
        if self.is_classified:
            raise ValueError(f"Cache {self.cache_id} already classified as '{self.kept.value}' ({self.reason}), cannot reclassify as '{kept.value}' ({reason})")
        self.kept = kept
        self.reason = reason

    def keep(self, reason: str) -> None:
        self.classify(Classification.KEEP, reason)

    def discard(self, reason: str) -> None:
        self.classify(Classification.DISCARD, reason)


# Supporting functions

def detect_repository() -> str:
    """Resolve the repository name from environment or gh CLI."""
    return os.environ.get("GITHUB_REPOSITORY") or subprocess.run(
        ["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
        capture_output=True, text=True
    ).stdout.strip()


# Pipeline

class CachePipeline:
    """Chainable pipeline for workflow cache pruning. Every method returns `self`."""

    def __init__(self, branch: str, repository: str, caches: list[WorkflowCache]) -> None:
        self.branch: str = branch
        self.repository: str = repository
        self.caches: list[WorkflowCache] = caches

    @classmethod
    def on_current_branch(cls) -> CachePipeline:
        """Detect the current branch and repository."""
        detected_branch = os.environ.get("BRANCH") or subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True
        ).stdout.strip()
        detected_repository = detect_repository()
        print(f"Branch: {detected_branch}")
        print(f"Repository: {detected_repository}")
        return cls(branch=detected_branch, repository=detected_repository, caches=[])

    def fetch_all_caches(self) -> CachePipeline:
        """Fetch all caches via REST API with pagination. Filtered by branch on feature branches."""
        all_raw_caches: list[dict] = []
        page_number = 1
        while True:
            api_url = f"repos/{self.repository}/actions/caches?per_page=100&page={page_number}"
            if self.branch != "main":
                api_url += f"&ref=refs/heads/{self.branch}"

            gh_result = subprocess.run(
                ["gh", "api", api_url],
                capture_output=True, text=True
            )
            if gh_result.returncode != 0:
                print(f"::error title=Fetch Failed::{gh_result.stderr.strip()}", file=sys.stderr)
                sys.exit(1)

            response = json.loads(gh_result.stdout)
            page_caches = response.get("actions_caches", [])
            all_raw_caches.extend(page_caches)

            if len(page_caches) < 100:
                break
            page_number += 1

        self.caches = [WorkflowCache.from_gh_json(raw_cache, self.repository) for raw_cache in all_raw_caches]
        print(f"Fetched {len(self.caches)} caches.")
        return self

    def newest_first(self) -> CachePipeline:
        """Sort caches newest-first by MAX(created_at, last_accessed_at)."""
        self.caches.sort(key=lambda cache: cache.effective_timestamp, reverse=True)
        return self

    def keep_latest_on_main(self, keep_last_on_main: int = DEFAULT_KEEP_LAST_ON_MAIN) -> CachePipeline:
        """On main: mark the last N caches per key prefix as kept, rest as overflow. No-op on feature branches."""
        if self.branch != "main":
            return self

        main_caches_by_prefix: dict[str, list[WorkflowCache]] = {}
        for cache in self.caches:
            if cache.ref == "refs/heads/main":
                main_caches_by_prefix.setdefault(cache.key_prefix, []).append(cache)

        for prefix, prefix_caches in main_caches_by_prefix.items():
            for position, cache in enumerate(prefix_caches):
                if cache.is_classified:
                    continue
                if position < keep_last_on_main:
                    cache.keep(f"main, #{position + 1} of {prefix}")
                else:
                    cache.discard(f"main overflow, #{position + 1} of {prefix}")

        return self

    def keep_within_grace_window(self, stale_minutes: int = DEFAULT_STALE_MINUTES) -> CachePipeline:
        """Mark unclassified caches: kept if within grace window, deletable if stale."""
        now = datetime.now(timezone.utc)
        for cache in self.caches:
            if cache.is_classified:
                continue
            cache_age_minutes = (now - cache.effective_timestamp).total_seconds() / 60
            if cache_age_minutes < stale_minutes:
                cache.keep(f"grace, {cache_age_minutes:.0f}m old, {cache.ref}")
            else:
                cache.discard(f"stale, {cache_age_minutes:.0f}m old, {cache.ref}")
        return self

    @staticmethod
    def _delete_one_cache(cache: WorkflowCache) -> WorkflowCache:
        """Delete a single cache via REST API. Annotates with the result. No printing."""
        cache_id_s = str(cache.cache_id)
        if DRY_RUN:
            cache.deleted = DeletionResult.MUTED
        else:
            delete_result = subprocess.run(
                ["gh", "api", "-X", "DELETE", f"repos/{cache.repository}/actions/caches/{cache_id_s}"],
                capture_output=True, text=True
            )
            if delete_result.returncode == 0:
                cache.deleted = DeletionResult.DELETED
            else:
                cache.deleted = DeletionResult.FAILED
                cache.delete_error = delete_result.stderr.strip()
        return cache

    def remove_discarded(self) -> CachePipeline:
        """Fan out deletion of all Discard-marked caches, collect results."""
        discarded_caches = [cache for cache in self.caches if cache.is_discarded]
        if not discarded_caches:
            print("Nothing to remove.")
            return self

        with ThreadPoolExecutor() as executor:
            list(executor.map(self._delete_one_cache, discarded_caches))

        for cache in discarded_caches:
            error_text = f"  {cache.delete_error}" if cache.delete_error else ""
            print(f"  gh api -X DELETE .../caches/{cache.cache_id}  # {cache.deleted.value.lower()}: {cache.reason}  ({cache.size_mb:.1f}MB){error_text}")

        return self

    def report(self, actor: Callable[[list[WorkflowCache]], None]) -> CachePipeline:
        """Pass the cache collection to an actor function."""
        actor(self.caches)
        return self


# Actors

def write_summary(caches: list[WorkflowCache]) -> None:
    """Write kept/discarded Markdown tables. Writes to GITHUB_STEP_SUMMARY or stdout."""
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    out = open(summary_path, "a") if summary_path else sys.stdout

    kept_caches = [cache for cache in caches if cache.is_kept]
    discarded_caches = [cache for cache in caches if cache.is_discarded]

    print(f"\n### Kept ({len(kept_caches)})\n", file=out)
    print("| ID | Key Prefix | Ref | Size | Last Accessed | Reason |", file=out)
    print("|----|------------|-----|------|---------------|--------|", file=out)
    for cache in kept_caches:
        print(f"| {cache.cache_id} | {cache.key_prefix} | {cache.ref} | {cache.size_mb:.1f}MB | {cache.last_accessed_at} | {cache.reason} |", file=out)

    print(f"\n### Discarded ({len(discarded_caches)})\n", file=out)
    print("| ID | Key Prefix | Ref | Size | Last Accessed | Reason | Result |", file=out)
    print("|----|------------|-----|------|---------------|--------|--------|", file=out)
    for cache in discarded_caches:
        deleted_display = cache.deleted.value if cache.deleted != DeletionResult.NONE else "Pending"
        print(f"| {cache.cache_id} | {cache.key_prefix} | {cache.ref} | {cache.size_mb:.1f}MB | {cache.last_accessed_at} | {cache.reason} | {deleted_display} |", file=out)

    total_discarded_size_mb = sum(cache.size_mb for cache in discarded_caches)
    dry_run_notice_s = " (DRY RUN)" if DRY_RUN else ""
    print(f"\n**Total:** {len(caches)} | **Kept:** {len(kept_caches)} | **Discarded:** {len(discarded_caches)} ({total_discarded_size_mb:.1f}MB){dry_run_notice_s}", file=out)

    if out is not sys.stdout:
        out.close()


# Main

if __name__ == "__main__":
    CachePipeline.on_current_branch() \
        .fetch_all_caches() \
        .newest_first() \
        .keep_latest_on_main() \
        .keep_within_grace_window() \
        .remove_discarded() \
        .report(write_summary)
