"""Small shared runtime helpers used by the repository scripts."""

from __future__ import annotations

import os
from pathlib import Path


def load_dotenv(path: Path) -> None:
    """Load simple KEY=VALUE pairs without overriding the process environment.

    This intentionally preserves the original scripts' narrow dotenv behavior:
    comments and blank lines are ignored, values may be quoted, and existing
    environment variables always take precedence.
    """
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("'\""))
