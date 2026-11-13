from __future__ import annotations

from pathlib import Path

import pytest

from noite import strrefs
from noite.ne import NeImage, Segment, c_literal

EXE = Path(__file__).resolve().parents[3] / "assets" / "NOITE.EXE"


@pytest.fixture(scope="module")
def image() -> NeImage:
    if not EXE.is_file():
        pytest.skip("assets/NOITE.EXE not extracted")
    return NeImage.load(EXE)


def test_segments_map_to_ghidra_selectors(image: NeImage) -> None:
    assert sorted(image.segments)[:2] == [0x1000, 0x1008]
    assert 0x1050 in image.segments  # DGROUP


def test_strings_from_the_real_exe(image: NeImage) -> None:
    assert image.c_string(0x1018, 0x36D8) == b"Erro Wave Mix"
    assert image.c_string(0x1010, 0xAF56) == b"Erro Fatal!"
    s = image.c_string(0x1020, 0xD534)
    assert s == b"fase4\\4fboydj\\maeemae.wav"
    assert c_literal(s) == '"fase4\\\\4fboydj\\\\maeemae.wav"'


def test_c_string_rejects_binary() -> None:
    img = NeImage({0x1018: Segment(0x1018, b"ab\x01c\0\0Ol\xe1\r\n\0xyz")})
    assert img.c_string(0x1018, 0) is None  # control byte
    assert img.c_string(0x1018, 5) is None  # empty string
    assert img.c_string(0x1018, 6) == b"Ol\xe1\r\n"
    assert img.c_string(0x1018, 13) is None  # no NUL before the end
    assert img.c_string(0x1028, 0) is None
    assert c_literal(b'Ol\xe1\r\n"\t') == '"Ol\\xe1\\r\\n\\"\\t"'


def test_candidates_from_disasm() -> None:
    disasm = "\n".join(
        [
            "1018:0000  PUSH 0x1018",
            "1018:0003  PUSH 0x36d8",
            "1018:0006  PUSH DS",
            "1018:0007  PUSH -0x50aa",
            "1018:000a  PUSH CS",
            "1018:000b  PUSH 0x10",
            "1018:000e  PUSH 0x10200004",
            "1018:0013  MOV DX, 0x1020",
            "1018:0016  MOV AX, 0x8",
            "1018:0019  MOV AX, 0x1050",
            "1018:001c  MOV DS, AX",
            "1018:001e  PUSH 0x4000000",
        ]
    )
    sels = [0x1018, 0x1020, 0x1050]
    assert strrefs.candidates(disasm, sels) == [
        (0x1018, 0x36D8),
        (0x1050, 0xAF56),
        (0x1018, 0x10),
        (0x1020, 0x4),
        (0x1020, 0x8),
    ]


def test_find_keeps_texty_targets_once() -> None:
    img = NeImage({0x1018: Segment(0x1018, b"\x01\x02\0\0hi\0")})
    disasm = "1018:0000  PUSH CS\n1018:0001  PUSH 0x4\n1018:0004  PUSH CS\n1018:0005  PUSH 0x4\n"
    disasm += "1018:0008  PUSH CS\n1018:0009  PUSH 0x0"
    refs = strrefs.find(disasm, img)
    assert [r.render() for r in refs] == ['- 1018:0004 "hi" (2 bytes)']
    assert strrefs.find(disasm, img, {"1018:0004"}) == []
