"""Where things live.

Every worktree under ``work/`` is a full checkout, but there is only one
tracker database: the one in the *main* checkout. Paths are therefore resolved
from git's common directory, so ``uv run noite`` behaves the same from the repo
root, from a unit's worktree, or from any subdirectory of either.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from noite import program


def _git(cwd: Path, *args: str) -> str:
    out = subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout
    return out.strip()


def repo_root(cwd: Path | None = None) -> Path:
    """The main checkout (the one owning ``.git``), even from inside a worktree."""
    env = os.environ.get("NOITE_ROOT")
    if env:
        return Path(env).resolve()
    common = _git(cwd or Path.cwd(), "rev-parse", "--path-format=absolute", "--git-common-dir")
    return Path(common).parent


def tree_root(cwd: Path | None = None) -> Path:
    """The checkout containing ``cwd`` (a worktree, or the main checkout)."""
    return Path(_git(cwd or Path.cwd(), "rev-parse", "--show-toplevel"))


def git_common_dir(root: Path) -> Path:
    return Path(_git(root, "rev-parse", "--path-format=absolute", "--git-common-dir"))


def db_path(root: Path | None = None) -> Path:
    env = os.environ.get("NOITE_DB")
    if env:
        return Path(env)
    return (root or repo_root()) / program.current().db


def work_dir(root: Path) -> Path:
    return root / "work"


def worktree_path(root: Path, unit: str) -> Path:
    return work_dir(root) / program.current().worktree_name(unit)


def branch_name(unit: str) -> str:
    return f"port/{program.current().worktree_name(unit)}"
