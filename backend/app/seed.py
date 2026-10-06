"""테이블 생성 + M1 개발용 시드 (alice🐰 / bob🐸 친구쌍).

실행: cd backend && uv run python -m app.seed
"""

import asyncio

from sqlalchemy.dialects.postgresql import insert

from app.db import SessionLocal, engine
from app.models import Base, Friendship, User


async def seed() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with SessionLocal() as session:
        await session.execute(
            insert(User)
            .values(
                [
                    {"id": "alice", "character_emoji": "🐰", "accessory": "", "room_theme": "cream"},
                    # bob에 악세사리를 줘야 수신 렌더링(친구 머리 위 🧢)을 검증할 수 있다
                    {"id": "bob", "character_emoji": "🐸", "accessory": "cap", "room_theme": "mint"},
                ]
            )
            .on_conflict_do_nothing()
        )
        await session.execute(
            insert(Friendship)
            .values([{"user_a": "alice", "user_b": "bob"}])
            .on_conflict_do_nothing()
        )
        await session.commit()
    print("seeded: alice🐰 ↔ bob🐸")


if __name__ == "__main__":
    asyncio.run(seed())
