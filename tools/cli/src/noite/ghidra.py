"""Read-only access to Ghidra through the ghidra-mcp bridge (``./ghidra-mcp.sh``).

The bridge speaks MCP over streamable HTTP: one ``initialize`` handshake, then
``tools/call`` requests carrying the session id. Responses may arrive as an SSE
stream; the last ``data:`` line is the JSON-RPC reply. Only listing and
decompiling tools are used — nothing here writes to the program.
"""

from __future__ import annotations

import json
import urllib.request
from collections.abc import Iterator, Sequence
from dataclasses import dataclass, field
from typing import Any, Protocol

DEFAULT_URL = "http://127.0.0.1:8000/mcp"
PROGRAM = "NOITE.EXE"


class GhidraError(RuntimeError):
    pass


@dataclass(frozen=True)
class FunctionInfo:
    addr: str  # seg:off
    name: str
    is_thunk: bool
    size: int | None = None
    signature: str | None = None
    plate: str | None = None
    decompile: str | None = None
    disasm: str | None = None
    ghidra_class: str | None = None
    callees: tuple[str, ...] = ()


@dataclass(frozen=True)
class StructInfo:
    name: str
    size: int
    fields: list[dict[str, Any]] = field(default_factory=list)


@dataclass(frozen=True)
class GlobalInfo:
    addr: str
    name: str
    type: str | None
    xrefs: int | None


class Source(Protocol):
    """What the importer needs from Ghidra (a fake in the tests)."""

    def list_functions(self) -> list[FunctionInfo]: ...

    def function_details(
        self, addrs: Sequence[str], *, decompile: bool
    ) -> dict[str, FunctionInfo]: ...

    def structs(self) -> list[StructInfo]: ...

    def globals(self) -> list[GlobalInfo]: ...


class McpClient:
    def __init__(self, url: str = DEFAULT_URL, timeout: float = 300) -> None:
        self.url = url
        self.timeout = timeout
        self.session: str | None = None
        self._id = 0

    def _post(self, body: dict[str, Any]) -> Any:
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        if self.session:
            headers["mcp-session-id"] = self.session
        req = urllib.request.Request(self.url, json.dumps(body).encode(), headers)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as r:
                self.session = r.headers.get("mcp-session-id") or self.session
                text = r.read().decode()
        except OSError as e:
            raise GhidraError(
                f"cannot reach the Ghidra MCP bridge at {self.url} ({e}); start Ghidra, "
                "Tools → GhidraMCP → Start MCP Server, then ./ghidra-mcp.sh"
            ) from e
        for line in text.splitlines():
            if line.startswith("data:"):
                text = line[5:]
        return json.loads(text) if text.strip() else None

    def _next_id(self) -> int:
        self._id += 1
        return self._id

    def connect(self) -> None:
        self._post(
            {
                "jsonrpc": "2.0",
                "id": self._next_id(),
                "method": "initialize",
                "params": {
                    "protocolVersion": "2025-06-18",
                    "capabilities": {},
                    "clientInfo": {"name": "noite", "version": "0"},
                },
            }
        )
        self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call(self, tool: str, args: dict[str, Any]) -> Any:
        """Call a tool and return its result parsed as JSON."""
        if self.session is None:
            self.connect()
        res = self._post(
            {
                "jsonrpc": "2.0",
                "id": self._next_id(),
                "method": "tools/call",
                "params": {"name": tool, "arguments": args},
            }
        )
        if res is None or "error" in res:
            raise GhidraError(f"{tool}: {res and res.get('error')}")
        texts = [c.get("text", "") for c in res.get("result", {}).get("content", [])]
        text = "\n".join(texts)
        if res.get("result", {}).get("isError") or text.startswith("Error"):
            raise GhidraError(f"{tool}: {text[:500]}")
        try:
            return json.loads(text)
        except json.JSONDecodeError as e:
            raise GhidraError(f"{tool}: not JSON: {text[:200]}") from e


def _chunks(seq: Sequence[str], n: int) -> Iterator[Sequence[str]]:
    for i in range(0, len(seq), n):
        yield seq[i : i + n]


def format_disasm(rows: list[dict[str, Any]]) -> str:
    return "\n".join(
        f"{r.get('address', '')}  {r.get('mnemonic', '')} {r.get('operands', '')}".rstrip()
        for r in rows
    )


class GhidraSource:
    """The live Ghidra program, read through :class:`McpClient`."""

    BATCH = 20  # get_functions' bulk limit

    def __init__(self, client: McpClient, program: str = PROGRAM) -> None:
        self.client = client
        self.program = program

    def list_functions(self) -> list[FunctionInfo]:
        res = self.client.call("find_functions", {"program": self.program, "limit": 0})
        return [
            FunctionInfo(addr=f["address"].lower(), name=f["name"], is_thunk=bool(f["is_thunk"]))
            for f in res["functions"]
            if not f.get("is_external")
        ]

    def function_details(self, addrs: Sequence[str], *, decompile: bool) -> dict[str, FunctionInfo]:
        fields = "signature,classification,plate_comment,callees,disassembly"
        if decompile:
            fields += ",decompiled_code"
        out: dict[str, FunctionInfo] = {}
        for chunk in _chunks(addrs, self.BATCH):
            res = self.client.call(
                "get_functions",
                {
                    "program": self.program,
                    "functions": ",".join(chunk),
                    "fields": fields,
                    "include_disasm": True,
                    "include_call_context": False,
                },
            )
            for ref, f in res["functions"].items():
                if "error" in f:
                    raise GhidraError(f"get_functions {ref}: {f['error']}")
                addr = f["address"].lower()
                out[addr] = FunctionInfo(
                    addr=addr,
                    name=f["name"],
                    is_thunk=f.get("classification") == "thunk",
                    size=f.get("size"),
                    signature=f.get("signature"),
                    plate=f.get("plate_comment") or None,
                    decompile=f.get("decompiled_code") if decompile else None,
                    disasm=format_disasm(f.get("disassembly") or []),
                    ghidra_class=f.get("classification"),
                    callees=tuple(sorted({c["address"].lower() for c in f.get("callees", [])})),
                )
        return out

    def structs(self) -> list[StructInfo]:
        res = self.client.call(
            "find_data_types", {"program": self.program, "kind": "struct", "limit": 0}
        )
        out = []
        for t in res["data_types"]:
            if t.get("category") != "/":  # the program's own types, not archives
                continue
            lay = self.client.call(
                "get_struct_layout", {"program": self.program, "struct_name": t["name"]}
            )
            out.append(StructInfo(name=t["name"], size=lay["size"], fields=lay["fields"]))
        return out

    def globals(self) -> list[GlobalInfo]:
        import re

        res = self.client.call(
            "list_globals", {"program": self.program, "limit": 0, "filter": "defined"}
        )
        out = []
        # "g_lives @ 1050:002a [Label] (short) xrefs=24"
        pat = re.compile(
            r"^(\S+) @ ([0-9a-fA-F]{4}:[0-9a-fA-F]{4}) \[[^\]]*\] \((.*)\) xrefs=(\d+)$"
        )
        for line in res["globals"]:
            m = pat.match(line)
            if m:
                out.append(GlobalInfo(m.group(2).lower(), m.group(1), m.group(3), int(m.group(4))))
        return out
