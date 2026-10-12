import os
import re
import subprocess
import sys
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Final, Iterator, NoReturn, TextIO

DEFAULT_STALE_MINUTES: Final[int] = int(os.environ.get("STALE_MINUTES", "11"))
DEFAULT_KEEP_LAST_ON_MAIN: Final[int] = int(os.environ.get("KEEP_LAST", "2"))
DRY_RUN: Final[bool] = os.environ.get("DRY_RUN", "true").lower() in ("true", "1", "yes")
DRY_RUN_NOTICE_S: Final[str] = " (DRY RUN)" if DRY_RUN else ""

NANOSECOND_TRUNCATION_PATTERN = re.compile(r'(\.\d{6})\d+')


class Classification(Enum):
    NONE = ""
    KEEP = "Keep"
    DISCARD = "Discard"


class DeletionResult(Enum):
    NONE = ""
    MUTED = "Muted"
    DELETED = "Deleted"
    FAILED = "Failed"


@dataclass(slots=True)
class Classifiable:
    """Classification state for `@dataclass(slots=True)` subclasses. Keyword-only so subclass fields without defaults may follow."""
    kept: Classification = field(default=Classification.NONE, kw_only=True)
    reason: str = field(default="", kw_only=True)

    @property
    def label(self) -> str:
        raise NotImplementedError

    @property
    def is_classified(self) -> bool:
        return self.kept != Classification.NONE

    @property
    def is_kept(self) -> bool:
        return self.kept == Classification.KEEP

    @property
    def is_discarded(self) -> bool:
        return self.kept == Classification.DISCARD

    def classify(self, kept: Classification, reason: str) -> None:
        """Set classification. Only allowed once -- raises if already classified or if NONE is passed."""
        if kept == Classification.NONE:
            raise ValueError(f"{self.label}: cannot classify as NONE")
        if self.is_classified:
            raise ValueError(f"{self.label} already classified as '{self.kept.value}' ({self.reason}), cannot reclassify as '{kept.value}' ({reason})")
        self.kept = kept
        self.reason = reason

    def keep(self, reason: str) -> None:
        self.classify(Classification.KEEP, reason)

    def discard(self, reason: str) -> None:
        self.classify(Classification.DISCARD, reason)


def parse_timestamp(iso_timestamp_s: str) -> datetime:
    """Parse GitHub's ISO 8601 timestamp. Truncates nanosecond precision to microseconds."""
    truncated_timestamp_s = NANOSECOND_TRUNCATION_PATTERN.sub(r'\1', iso_timestamp_s)
    return datetime.fromisoformat(truncated_timestamp_s.replace("Z", "+00:00"))


def detect_branch() -> str:
    """Resolve the branch name from environment or git."""
    return os.environ.get("BRANCH") or subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True, text=True
    ).stdout.strip()


def detect_repository() -> str:
    """Resolve the repository name from environment or gh CLI."""
    return os.environ.get("GITHUB_REPOSITORY") or subprocess.run(
        ["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
        capture_output=True, text=True
    ).stdout.strip()


def fail_fetch(stderr_s: str) -> NoReturn:
    print(f"::error title=Fetch Failed::{stderr_s.strip()}", file=sys.stderr)
    sys.exit(1)


@contextmanager
def summary_output() -> Iterator[TextIO]:
    """Yield GITHUB_STEP_SUMMARY opened for append, or stdout when unset."""
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        yield sys.stdout
        return
    with open(summary_path, "a") as out:
        yield out
