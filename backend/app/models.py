from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    character_emoji: Mapped[str] = mapped_column(String(16), default="🎵")


class Friendship(Base):
    """정렬된 쌍 1행으로 양방향 친구관계를 표현한다 (user_a < user_b)."""

    __tablename__ = "friendships"

    user_a: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
    user_b: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
