"""인메모리 presence 저장소.

presence는 휘발성 — 서버 재시작 시 클라이언트가 재접속하며 재보고하므로
DB에 두지 않는다. last_seen 기반 TTL로 좀비 연결(앱 suspend 등)을 정리한다.
"""

import time
from dataclasses import dataclass, field


@dataclass
class PresenceEntry:
    track: str
    artist: str
    is_playing: bool
    source: str
    last_seen: float = field(default_factory=time.monotonic)


class PresenceStore:
    def __init__(self) -> None:
        self._entries: dict[str, PresenceEntry] = {}

    def update(self, user_id: str, entry: PresenceEntry) -> None:
        self._entries[user_id] = entry

    def get(self, user_id: str) -> PresenceEntry | None:
        return self._entries.get(user_id)

    def remove(self, user_id: str) -> PresenceEntry | None:
        return self._entries.pop(user_id, None)

    def sweep_expired(self, ttl_seconds: float) -> list[str]:
        """last_seen이 ttl을 넘긴 user_id를 제거하고 돌려준다."""
        now = time.monotonic()
        expired = [
            user_id
            for user_id, entry in self._entries.items()
            if now - entry.last_seen > ttl_seconds
        ]
        for user_id in expired:
            del self._entries[user_id]
        return expired
