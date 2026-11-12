from __future__ import annotations

import pytest
from typer.testing import CliRunner

from noite.cli import app


@pytest.mark.parametrize("flag", ["-Doptimize=ReleaseFast", "-fllvm", "--release=safe"])
def test_build_refuses_release_and_llvm(flag: str) -> None:
    res = CliRunner().invoke(app, ["build", flag])
    assert res.exit_code == 1
    assert "Debug with the self-hosted backend" in res.output
