"""WS presence 허브.

단일 WebSocket(/ws?user_id=...)으로 자가보고 수신 + 친구 상태 push를 모두 처리한다.
연결 수명 = presence: 끊기면 즉시 퇴장으로 판정하고, TTL 스위퍼가 좀비 연결을 정리한다.
"""

import asyncio
import logging
from datetime import datetime, timezone
from typing import Awaitable, Callable

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import ValidationError

from app.config import settings
from app.presence import PresenceEntry, PresenceStore
from app.schemas import FriendPresencePush, NowPlayingReport, client_message_adapter

logger = logging.getLogger("ipmusic.ws")

router = APIRouter()

# WU3에서 DB 조회로 교체 — 그 전까지는 하드코딩 친구쌍/이모지
FRIENDS: dict[str, list[str]] = {"alice": ["bob"], "bob": ["alice"]}
EMOJIS: dict[str, str] = {"alice": "🐰", "bob": "🐸"}

GetFriends = Callable[[str], Awaitable[list[str]]]
GetEmoji = Callable[[str], Awaitable[str]]


async def _default_get_friends(user_id: str) -> list[str]:
    return FRIENDS.get(user_id, [])


async def _default_get_emoji(user_id: str) -> str:
    return EMOJIS.get(user_id, "🎵")


class ConnectionManager:
    def __init__(self) -> None:
        self._sockets: dict[str, WebSocket] = {}

    def connect(self, user_id: str, websocket: WebSocket) -> None:
        self._sockets[user_id] = websocket

    def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        # 같은 user_id로 새 연결이 이미 들어왔다면 그 연결은 남겨둔다
        if self._sockets.get(user_id) is websocket:
            del self._sockets[user_id]

    def is_online(self, user_id: str) -> bool:
        return user_id in self._sockets

    async def send_to(self, user_id: str, message: FriendPresencePush) -> None:
        websocket = self._sockets.get(user_id)
        if websocket is None:
            return
        try:
            await websocket.send_text(message.model_dump_json())
        except Exception:
            logger.warning("send to %s failed; dropping socket", user_id)
            self._sockets.pop(user_id, None)


class PresenceHub:
    """presence 상태 변화를 친구들에게 전파하는 중심 객체."""

    def __init__(
        self,
        store: PresenceStore | None = None,
        manager: ConnectionManager | None = None,
        get_friends: GetFriends = _default_get_friends,
        get_emoji: GetEmoji = _default_get_emoji,
    ) -> None:
        self.store = store or PresenceStore()
        self.manager = manager or ConnectionManager()
        self.get_friends = get_friends
        self.get_emoji = get_emoji

    async def broadcast_playing(self, user_id: str, entry: PresenceEntry) -> None:
        push = FriendPresencePush(
            event="playing",
            friend_id=user_id,
            emoji=await self.get_emoji(user_id),
            track=entry.track,
            artist=entry.artist,
            is_playing=entry.is_playing,
            ts=datetime.now(timezone.utc),
        )
        for friend_id in await self.get_friends(user_id):
            await self.manager.send_to(friend_id, push)

    async def broadcast_stopped(self, user_id: str) -> None:
        push = FriendPresencePush(
            event="stopped",
            friend_id=user_id,
            ts=datetime.now(timezone.utc),
        )
        for friend_id in await self.get_friends(user_id):
            await self.manager.send_to(friend_id, push)

    async def send_snapshot(self, user_id: str) -> None:
        """접속 직후, 이미 재생 중인 친구들의 상태를 보내준다."""
        for friend_id in await self.get_friends(user_id):
            entry = self.store.get(friend_id)
            if entry is None:
                continue
            push = FriendPresencePush(
                event="playing",
                friend_id=friend_id,
                emoji=await self.get_emoji(friend_id),
                track=entry.track,
                artist=entry.artist,
                is_playing=entry.is_playing,
                ts=datetime.now(timezone.utc),
            )
            await self.manager.send_to(user_id, push)

    async def mark_stopped(self, user_id: str) -> None:
        """stopped 보고 / disconnect / TTL 만료가 모두 이 경로로 수렴한다."""
        if self.store.remove(user_id) is not None:
            await self.broadcast_stopped(user_id)

    async def sweep_loop(self) -> None:
        while True:
            await asyncio.sleep(settings.presence_sweep_interval_seconds)
            for user_id in self.store.sweep_expired(settings.presence_ttl_seconds):
                logger.info("presence TTL expired: %s", user_id)
                await self.broadcast_stopped(user_id)


hub = PresenceHub()


@router.websocket("/ws")
async def ws_endpoint(websocket: WebSocket, user_id: str) -> None:
    await websocket.accept()
    hub.manager.connect(user_id, websocket)
    logger.info("connected: %s", user_id)
    await hub.send_snapshot(user_id)
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                message = client_message_adapter.validate_json(raw)
            except ValidationError:
                logger.warning("invalid message from %s: %.200s", user_id, raw)
                continue
            if isinstance(message, NowPlayingReport):
                entry = PresenceEntry(
                    track=message.track,
                    artist=message.artist,
                    is_playing=message.is_playing,
                    source=message.source,
                )
                hub.store.update(user_id, entry)
                await hub.broadcast_playing(user_id, entry)
            else:  # StoppedReport
                await hub.mark_stopped(user_id)
    except WebSocketDisconnect:
        logger.info("disconnected: %s", user_id)
    finally:
        hub.manager.disconnect(user_id, websocket)
        await hub.mark_stopped(user_id)
