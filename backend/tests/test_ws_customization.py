"""M2 캐릭터 꾸미기 (set_customization) 테스트.

DB가 없어도 Directory 메모리 상태로 동작해야 한다 (upsert는 fail-soft).
"""

from fastapi.testclient import TestClient

from app.main import app
from app.ws import directory


def _now_playing(track: str = "Ditto", artist: str = "NewJeans") -> dict:
    return {
        "type": "now_playing",
        "track": track,
        "artist": artist,
        "is_playing": True,
        "source": "apple_music",
        "ts": "2026-10-07T12:00:00Z",
    }


def _customization(accessory: str, room_theme: str = "cream") -> dict:
    return {
        "type": "set_customization",
        "accessory": accessory,
        "room_theme": room_theme,
        "ts": "2026-10-07T12:00:00Z",
    }


def test_push_carries_accessory_after_customization() -> None:
    client = TestClient(app)
    directory.accessories.pop("alice", None)
    with client.websocket_connect("/ws?user_id=bob") as bob:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            alice.send_json(_customization("ribbon"))
            alice.send_json(_now_playing())
            push = bob.receive_json()
            assert push["type"] == "friend_presence"
            assert push["accessory"] == "ribbon"


def test_change_while_playing_rebroadcasts() -> None:
    client = TestClient(app)
    directory.accessories.pop("alice", None)
    with client.websocket_connect("/ws?user_id=bob") as bob:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            alice.send_json(_now_playing())
            assert bob.receive_json()["accessory"] == ""
            # 재생 중 꾸미기 변경 → 친구에게 즉시 재broadcast
            alice.send_json(_customization("crown"))
            push = bob.receive_json()
            assert push["event"] == "playing"
            assert push["accessory"] == "crown"


def test_snapshot_carries_accessory() -> None:
    client = TestClient(app)
    directory.accessories["alice"] = "glasses"
    with client.websocket_connect("/ws?user_id=alice") as alice:
        alice.send_json(_now_playing(track="밤편지", artist="아이유"))
        with client.websocket_connect("/ws?user_id=bob") as bob:
            push = bob.receive_json()
            assert push["friend_id"] == "alice"
            assert push["accessory"] == "glasses"
    directory.accessories.pop("alice", None)


def test_customization_without_playing_sends_nothing() -> None:
    client = TestClient(app)
    directory.accessories.pop("alice", None)
    with client.websocket_connect("/ws?user_id=bob") as bob:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            # 재생 중이 아니면 꾸미기 변경만으로 push가 가지 않는다
            alice.send_json(_customization("cap"))
            alice.send_json(_now_playing())
            push = bob.receive_json()  # 첫 push는 now_playing에 의한 것
            assert push["track"] == "Ditto"
            assert push["accessory"] == "cap"
