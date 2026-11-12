from __future__ import annotations

import pytest

from noite.classify import class_names, classify, initial_status
from noite.db import Kind, Status

CLASSES = class_names(
    [
        "Actor2D",
        "StatusBar",
        "GridBackdrop",
        "Object3D",
        "Player",
        "SceneObjectVtbl",
        "ActorVbtable",
        "RECT",
        "BITMAPINFO",
    ]
)


def test_class_names() -> None:
    assert {"actor2d", "status_bar", "grid_backdrop", "object3d", "player"} == CLASSES


@pytest.mark.parametrize(
    ("addr", "name", "kind"),
    [
        ("1108:0000", "WAVEMIXACTIVATE", Kind.API),
        ("1008:001a", "entry", Kind.CRT),
        ("1020:0000", "handler_2fpontoc", Kind.HANDLER),
        ("1010:8ff4", "actor2d_move_tick", Kind.DEAD),
        ("1010:9000", "actor2d_show_thunk", Kind.DEAD),
        ("1010:3116", "player2d_is_player", Kind.DEAD),
        ("1018:2608", "FUN_1018_2608", Kind.DEAD),
        ("1010:77b6", "object3d_get_world_x_thunk_4be", Kind.THUNK),
        ("1010:0c80", "backdrop_ctor", Kind.CTOR),
        ("1010:1000", "scene_object_ctor_default", Kind.CTOR),
        ("1010:1258", "frame_vector_dtor", Kind.DTOR),
        ("1010:e93e", "game_create_player_default", Kind.DEFAULT),
        ("1010:0ea6", "backdrop_as_grid_backdrop_default", Kind.DEFAULT),
        ("1010:1c44", "scene_object_is_actor2d", Kind.TYPE_TEST),  # not a ctor: "actor2d"
        ("1010:46b2", "status_bar_is_status_bar", Kind.TYPE_TEST),
        ("1010:e27a", "object_list_is_full", Kind.METHOD),
        ("1010:2000", "scene_object_is_scroll_target", Kind.METHOD),
        ("1018:4000", "WinMain", Kind.PLATFORM),
        ("1018:4100", "app_paint", Kind.PLATFORM),
        ("1010:041c", "load_dib", Kind.METHOD),
    ],
)
def test_classify(addr: str, name: str, kind: Kind) -> None:
    got, _ = classify(addr, name, ghidra_thunk=False, callees=(), classes=CLASSES)
    assert got is kind


def test_thunk_absorbed_by_its_single_target() -> None:
    kind, by = classify(
        "1010:77b6", "x_thunk_4be", ghidra_thunk=False, callees=("1010:4eb4",), classes=CLASSES
    )
    assert (kind, by) == (Kind.THUNK, "1010:4eb4")
    _, by = classify(
        "1010:77b6", "x_thunk", ghidra_thunk=False, callees=("1010:1", "1010:2"), classes=CLASSES
    )
    assert by is None


def test_initial_status() -> None:
    assert initial_status(Kind.CRT) is Status.REPLACED
    assert initial_status(Kind.API) is Status.REPLACED
    assert initial_status(Kind.DEAD) is Status.DEAD
    for k in (Kind.THUNK, Kind.DEFAULT, Kind.TYPE_TEST):
        assert initial_status(k) is Status.ABSORBED
    for k in (Kind.METHOD, Kind.CTOR, Kind.HANDLER, Kind.PLATFORM):
        assert initial_status(k) is Status.PENDING
