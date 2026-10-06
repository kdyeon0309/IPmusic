"""WS 메시지 스키마.

클라이언트→서버: now_playing / stopped (자가보고)
서버→클라이언트: friend_presence (친구 상태 push)
"""

from datetime import datetime
from typing import Annotated, Literal, Union

from pydantic import BaseModel, Field, TypeAdapter


class NowPlayingReport(BaseModel):
    type: Literal["now_playing"]
    track: str
    artist: str
    is_playing: bool
    source: Literal["apple_music", "spotify"] = "apple_music"
    ts: datetime


class StoppedReport(BaseModel):
    type: Literal["stopped"]
    ts: datetime


class SetCustomization(BaseModel):
    """내 캐릭터 꾸미기 변경 (M2). 서버는 저장·전파만 하고 코드 해석은 클라이언트 몫."""

    type: Literal["set_customization"]
    accessory: str = Field(default="", max_length=32)
    room_theme: str = Field(default="cream", max_length=32)
    ts: datetime


ClientMessage = Annotated[
    Union[NowPlayingReport, StoppedReport, SetCustomization],
    Field(discriminator="type"),
]

client_message_adapter: TypeAdapter[ClientMessage] = TypeAdapter(ClientMessage)


class FriendPresencePush(BaseModel):
    type: Literal["friend_presence"] = "friend_presence"
    event: Literal["playing", "stopped"]
    friend_id: str
    emoji: str = ""
    accessory: str = ""
    track: str = ""
    artist: str = ""
    is_playing: bool = False
    ts: datetime
