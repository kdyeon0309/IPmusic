"""곡 추천 저장 계층 (M2).

기본은 인메모리 repo — pytest/DB 없는 개발 모드에서 그대로 동작한다.
main.py lifespan이 DB 로드에 성공하면 DbRecommendationRepo로 승격한다
(directory.load_from_db / persist 플래그와 같은 fail-soft 패턴).
"""

from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone


@dataclass
class PendingRecommendation:
    id: int
    sender_id: str
    receiver_id: str
    track: str
    artist: str
    store_id: str
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


class RecommendationRepo:
    """인메모리 구현 — 서버 재시작 시 사라진다 (개발/테스트용)."""

    def __init__(self) -> None:
        self._items: dict[int, PendingRecommendation] = {}
        self._acked: set[int] = set()
        self._next_id = 1

    async def add(self, sender_id: str, receiver_id: str, track: str, artist: str,
                  store_id: str) -> PendingRecommendation:
        item = PendingRecommendation(
            id=self._next_id, sender_id=sender_id, receiver_id=receiver_id,
            track=track, artist=artist, store_id=store_id,
        )
        self._next_id += 1
        self._items[item.id] = item
        return item

    async def pending_for(self, user_id: str) -> list[PendingRecommendation]:
        return [
            item for item in self._items.values()
            if item.receiver_id == user_id and item.id not in self._acked
        ]

    async def ack(self, recommendation_id: int, user_id: str) -> None:
        item = self._items.get(recommendation_id)
        if item is not None and item.receiver_id == user_id:
            self._acked.add(recommendation_id)


class DbRecommendationRepo(RecommendationRepo):
    """Postgres 구현 — 동일 인터페이스. pending은 미확인 + 7일 이내 최신 10건."""

    PENDING_LIMIT = 10
    PENDING_MAX_AGE = timedelta(days=7)

    async def add(self, sender_id: str, receiver_id: str, track: str, artist: str,
                  store_id: str) -> PendingRecommendation:
        from app.db import SessionLocal
        from app.models import Recommendation

        async with SessionLocal() as session:
            row = Recommendation(
                sender_id=sender_id, receiver_id=receiver_id,
                track=track, artist=artist, store_id=store_id,
            )
            session.add(row)
            await session.commit()
            await session.refresh(row)
        return PendingRecommendation(
            id=row.id, sender_id=row.sender_id, receiver_id=row.receiver_id,
            track=row.track, artist=row.artist, store_id=row.store_id,
            created_at=row.created_at,
        )

    async def pending_for(self, user_id: str) -> list[PendingRecommendation]:
        from sqlalchemy import select

        from app.db import SessionLocal
        from app.models import Recommendation

        cutoff = datetime.now(timezone.utc) - self.PENDING_MAX_AGE
        async with SessionLocal() as session:
            rows = (
                await session.execute(
                    select(Recommendation)
                    .where(
                        Recommendation.receiver_id == user_id,
                        Recommendation.acked_at.is_(None),
                        Recommendation.created_at > cutoff,
                    )
                    .order_by(Recommendation.created_at.desc())
                    .limit(self.PENDING_LIMIT)
                )
            ).scalars().all()
        return [
            PendingRecommendation(
                id=r.id, sender_id=r.sender_id, receiver_id=r.receiver_id,
                track=r.track, artist=r.artist, store_id=r.store_id,
                created_at=r.created_at,
            )
            for r in rows
        ]

    async def ack(self, recommendation_id: int, user_id: str) -> None:
        from sqlalchemy import update

        from app.db import SessionLocal
        from app.models import Recommendation

        async with SessionLocal() as session:
            await session.execute(
                update(Recommendation)
                .where(
                    Recommendation.id == recommendation_id,
                    Recommendation.receiver_id == user_id,  # 본인 것만
                    Recommendation.acked_at.is_(None),
                )
                .values(acked_at=datetime.now(timezone.utc))
            )
            await session.commit()
