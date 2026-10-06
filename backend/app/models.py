from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    character_emoji: Mapped[str] = mapped_column(String(16), default="🎵")
    # M2 꾸미기: 악세사리 프리셋 코드("" = 없음)와 방 테마. 렌더링 매핑은 클라이언트가 가진다.
    accessory: Mapped[str] = mapped_column(String(32), default="", server_default="")
    room_theme: Mapped[str] = mapped_column(String(32), default="cream", server_default="cream")


class Friendship(Base):
    """정렬된 쌍 1행으로 양방향 친구관계를 표현한다 (user_a < user_b)."""

    __tablename__ = "friendships"

    user_a: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
    user_b: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)


class Recommendation(Base):
    """곡 추천 (M2) — 말풍선과 달리 '선물'이라 영속: 수신자가 오프라인이어도
    다음 접속 시 pending으로 전달되고, 확인(ack)하면 다시 오지 않는다."""

    __tablename__ = "recommendations"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    sender_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    receiver_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    track: Mapped[str] = mapped_column(String(256))
    artist: Mapped[str] = mapped_column(String(256))
    # 애플뮤직 카탈로그 ID (MPMediaItem.playbackStoreID). 로컬 파일 곡은 "".
    store_id: Mapped[str] = mapped_column(String(32), default="", server_default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    acked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
