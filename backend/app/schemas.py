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
    # 애플뮤직 카탈로그 ID (M2) — 없으면 "". 기본값이라 구버전 클라이언트도 유효.
    store_id: str = ""
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


class BubbleSend(BaseModel):
    """말풍선 전송 (M2). 비영속 — 수신자가 오프라인이면 유실된다 (영속화는 M3 메신저)."""

    type: Literal["bubble"]
    to: str
    text: str = Field(min_length=1, max_length=50)
    ts: datetime


class RecommendSend(BaseModel):
    """곡 추천 전송 (M2). 영속 — 수신자가 오프라인이면 다음 접속 시 전달."""

    type: Literal["recommend"]
    to: str
    track: str = Field(max_length=256)
    artist: str = Field(max_length=256)
    store_id: str = Field(default="", max_length=32)
    ts: datetime


class RecommendationAck(BaseModel):
    """추천 확인 — 이후 재접속 시 다시 전달되지 않는다."""

    type: Literal["recommendation_ack"]
    recommendation_id: int
    ts: datetime


ClientMessage = Annotated[
    Union[
        NowPlayingReport,
        StoppedReport,
        SetCustomization,
        BubbleSend,
        RecommendSend,
        RecommendationAck,
    ],
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


class FriendBubblePush(BaseModel):
    type: Literal["friend_bubble"] = "friend_bubble"
    from_id: str
    from_emoji: str = ""
    text: str
    ts: datetime


class FriendRecommendationPush(BaseModel):
    type: Literal["friend_recommendation"] = "friend_recommendation"
    id: int
    from_id: str
    from_emoji: str = ""
    track: str
    artist: str
    store_id: str = ""
    ts: datetime
