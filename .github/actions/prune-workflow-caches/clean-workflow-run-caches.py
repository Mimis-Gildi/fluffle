#!/usr/bin/env python3
"""Prune workflow caches. Same functional pipeline as the run pruner."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import Callable, Final

LOG_PAGE_SIZE: Final[int] = 25
DEFAULT_STALE_MINUTES: Final[int] = int(os.environ.get("STALE_MINUTES", "11"))
DEFAULT_KEEP_LAST_ON_MAIN: Final[int] = int(os.environ.get("KEEP_LAST", "2"))
DRY_RUN: Final[bool] = os.environ.get("DRY_RUN", "true").lower() in ("true", "1", "yes")


# Supporting functions

def parse_cache_timestamp(iso_timestamp_s: str) -> datetime:
    """Parse GitHub's ISO 8601 timestamp into a timezone-aware datetime."""
    return datetime.fromisoformat(iso_timestamp_s.replace("Z", "+00:00"))


def cache_effective_timestamp(cache: dict) -> datetime:
    """MAX(created_at, last_accessed_at) -- defensive against missing or stale last_accessed_at."""
    created = parse_cache_timestamp(cache.get("created_at", "1970-01-01T00:00:00Z"))
    accessed = parse_cache_timestamp(cache.get("last_accessed_at", "1970-01-01T00:00:00Z"))
    return max(created, accessed)


def detect_repository() -> str:
    """Resolve the repository name from environment or gh CLI."""
    return os.environ.get("GITHUB_REPOSITORY") or subprocess.run(
        ["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
        capture_output=True, text=True
    ).stdout.strip()


# Pipeline

class CachePipeline:
    """Chainable pipeline for workflow cache pruning. Every method returns `self`."""

    def __init__(self, branch: str, repository: str, caches: list[dict]) -> None:
        self.branch: str = branch
        self.repository: str = repository
        self.caches: list[dict] = caches

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
        all_caches: list[dict] = []
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
            all_caches.extend(page_caches)

            if len(page_caches) < 100:
                break
            page_number += 1

        self.caches = all_caches
        print(f"Fetched {len(self.caches)} caches.")
        return self

    def newest_first(self) -> CachePipeline:
        """Sort caches newest-first by MAX(created_at, last_accessed_at)."""
        self.caches.sort(key=cache_effective_timestamp, reverse=True)
        return self

    def keep_latest_on_main(self, keep_last_on_main: int = DEFAULT_KEEP_LAST_ON_MAIN) -> CachePipeline:
        """On main: mark the last N caches per key as kept, rest as overflow. No-op on feature branches."""
        if self.branch != "main":
            return self

        main_caches_by_key: dict[str, list[dict]] = {}
        for cache in self.caches:
            if cache.get("ref") == "refs/heads/main":
                main_caches_by_key.setdefault(cache["key"], []).append(cache)

        for cache_key, key_caches in main_caches_by_key.items():
            for position, cache in enumerate(key_caches):
                if position < keep_last_on_main:
                    cache["kept"] = "Keep"
                    cache["reason"] = f"main, #{position + 1} of {cache_key}"
                else:
                    cache["kept"] = "Discard"
                    cache["reason"] = f"main overflow, #{position + 1} of {cache_key}"

        return self

    def keep_within_grace_window(self, stale_minutes: int = DEFAULT_STALE_MINUTES) -> CachePipeline:
        """Mark unclassified caches: kept if within a grace window, deletable if stale."""
        now = datetime.now(timezone.utc)
        for cache in self.caches:
            if "kept" in cache:
                continue
            effective_timestamp = cache_effective_timestamp(cache)
            cache_age_minutes = (now - effective_timestamp).total_seconds() / 60
            cache_ref = cache.get("ref", "unknown")
            if cache_age_minutes < stale_minutes:
                cache["kept"] = "Keep"
                cache["reason"] = f"grace, {cache_age_minutes:.0f}m old, {cache_ref}"
            else:
                cache["kept"] = "Discard"
                cache["reason"] = f"stale, {cache_age_minutes:.0f}m old, {cache_ref}"
        return self

    @staticmethod
    def _delete_one_cache(cache: dict) -> dict:
        """Delete a single cache via REST API. Annotates the cache dict with the result. No printing."""
        cache_id_s = str(cache["id"])
        repository = cache["_repository"]
        if DRY_RUN:
            cache["deleted"] = "Muted"
        else:
            delete_result = subprocess.run(
                ["gh", "api", "-X", "DELETE", f"repos/{repository}/actions/caches/{cache_id_s}"],
                capture_output=True, text=True
            )
            if delete_result.returncode == 0:
                cache["deleted"] = "Deleted"
            else:
                cache["deleted"] = "Failed"
                cache["delete_error"] = delete_result.stderr.strip()
        return cache

    def remove_discarded(self) -> CachePipeline:
        """Fan out deletion of all Discard-marked caches, collect results."""
        discarded_caches = [cache for cache in self.caches if cache.get("kept") == "Discard"]
        if not discarded_caches:
            print("Nothing to remove.")
            return self

        for cache in discarded_caches:
            cache["_repository"] = self.repository

        with ThreadPoolExecutor() as executor:
            list(executor.map(self._delete_one_cache, discarded_caches))

        for cache in discarded_caches:
            cache_id_s = str(cache["id"])
            deleted_status = cache["deleted"]
            error_text = f"  {cache.get('delete_error', '')}" if cache.get("delete_error") else ""
            size_mb = cache.get("size_in_bytes", 0) / (1024 * 1024)
            print(f"  gh api -X DELETE .../caches/{cache_id_s}  # {deleted_status.lower()}: {cache['reason']}  ({size_mb:.1f}MB){error_text}")

        return self

    def report(self, actor: Callable[[list[dict]], None]) -> CachePipeline:
        """Pass the cache collection to an actor function."""
        actor(self.caches)
        return self


# Actors

def write_summary(caches: list[dict]) -> None:
    """Write kept/discarded Markdown tables. Writes to GITHUB_STEP_SUMMARY or stdout."""
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    out = open(summary_path, "a") if summary_path else sys.stdout

    kept_caches = [cache for cache in caches if cache.get("kept") == "Keep"]
    discarded_caches = [cache for cache in caches if cache.get("kept") == "Discard"]

    print(f"\n### Kept ({len(kept_caches)})\n", file=out)
    print("| ID | Key | Ref | Size | Last Accessed | Reason |", file=out)
    print("|----|-----|-----|------|---------------|--------|", file=out)
    for cache in kept_caches:
        size_mb = cache.get("size_in_bytes", 0) / (1024 * 1024)
        print(f"| {cache['id']} | {cache['key']} | {cache.get('ref', '')} | {size_mb:.1f}MB | {cache.get('last_accessed_at', '')} | {cache['reason']} |", file=out)

    print(f"\n### Discarded ({len(discarded_caches)})\n", file=out)
    print("| ID | Key | Ref | Size | Last Accessed | Reason | Result |", file=out)
    print("|----|-----|-----|------|---------------|--------|--------|", file=out)
    for cache in discarded_caches:
        size_mb = cache.get("size_in_bytes", 0) / (1024 * 1024)
        deleted_status = cache.get("deleted", "Pending")
        print(f"| {cache['id']} | {cache['key']} | {cache.get('ref', '')} | {size_mb:.1f}MB | {cache.get('last_accessed_at', '')} | {cache['reason']} | {deleted_status} |", file=out)

    total_discarded_size_mb = sum(cache.get("size_in_bytes", 0) for cache in discarded_caches) / (1024 * 1024)
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
