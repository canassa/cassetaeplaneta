"""Classify a Ghidra function into a port ``Kind`` and its initial ``Status``.

The rules lean on the naming conventions of the Ghidra pass (``CLAUDE.md`` and
the analysis ledger): adjustor thunks are ``<impl>_thunk[_<k>]``, default
virtual stubs ``*_default``, type tests ``*_is_<class>`` / ``*_as_<class>``,
constructors and destructors ``*_ctor*`` / ``*_dtor``, per-scene handlers
``handler_<scene>``. Segment 1008 is the MSVC C runtime and 1108 the import
thunks. Order matters: the first rule that matches wins.
"""

from __future__ import annotations

import re
from collections.abc import Iterable

from noite.db import Kind, Status

CRT_SEGMENT = "1008"
API_SEGMENT = "1108"

# Classes that are never instantiated (no constructor stores their vtables):
# Actor2D and the Player2D derived from it.
DEAD_PREFIXES = ("actor2d_", "player2d_")
# Unreferenced duplicate bodies left in the binary.
DEAD_ADDRS = frozenset({"1010:468c", "1018:2608", "1018:2686"})

# The Win16 shell: replaced by the platform layer, not ported line by line.
PLATFORM_NAMES = frozenset({"WinMain", "?APPWNDPROC@@ZCJIIIJ@Z", "?APPABOUT@@ZCHIIIJ@Z"})
PLATFORM_PREFIXES = ("app_",)

_THUNK = re.compile(r"_thunk(_[0-9a-f]+)?$")
_CTOR = re.compile(r"(^|_)ctor(_|$)")
_DTOR = re.compile(r"(^|_)dtor(_|$)")
_DEFAULT = re.compile(r"_default$")


def class_names(struct_names: Iterable[str]) -> frozenset[str]:
    """snake_case class names from the program's structs (``StatusBar`` →
    ``status_bar``, ``Actor2D`` → ``actor2d``), skipping SDK types and vtables."""
    out = set()
    for n in struct_names:
        if n.isupper() or n.endswith(("Vtbl", "Vbtable")):
            continue
        out.add(re.sub(r"(?<=[a-z])([A-Z])", r"_\1", n).lower())
    return frozenset(out)


def is_type_test(name: str, classes: frozenset[str]) -> bool:
    m = re.search(r"_(?:is|as)_([a-z0-9_]+)$", name)
    return m is not None and m.group(1) in classes


def classify(
    addr: str,
    name: str,
    *,
    ghidra_thunk: bool,
    callees: Iterable[str],
    classes: frozenset[str],
) -> tuple[Kind, str | None]:
    """Return ``(kind, absorbed_by)``; ``absorbed_by`` is a thunk's single target."""
    seg = addr[:4]
    if seg == API_SEGMENT:
        return Kind.API, None
    if seg == CRT_SEGMENT:
        return Kind.CRT, None
    if name.startswith("handler_"):
        return Kind.HANDLER, None
    if addr in DEAD_ADDRS or name.startswith(DEAD_PREFIXES):
        return Kind.DEAD, None
    if _THUNK.search(name) or ghidra_thunk:
        targets = sorted(set(callees) - {addr})
        return Kind.THUNK, targets[0] if len(targets) == 1 else None
    if _CTOR.search(name):
        return Kind.CTOR, None
    if _DTOR.search(name):
        return Kind.DTOR, None
    if _DEFAULT.search(name):
        return Kind.DEFAULT, None
    if is_type_test(name, classes):
        return Kind.TYPE_TEST, None
    if name in PLATFORM_NAMES or name.startswith(PLATFORM_PREFIXES):
        return Kind.PLATFORM, None
    return Kind.METHOD, None


def initial_status(kind: Kind) -> Status:
    match kind:
        case Kind.CRT | Kind.API:
            return Status.REPLACED
        case Kind.DEAD:
            return Status.DEAD
        case Kind.THUNK | Kind.DEFAULT | Kind.TYPE_TEST:
            return Status.ABSORBED
        case _:
            return Status.PENDING
