import asyncio
import contextlib
import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI

from app.ws import directory, hub, router as ws_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ipmusic.main")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    try:
        await directory.load_from_db()
        # DB가 살아 있으면 추천 저장도 DB로 승격 (기본은 인메모리)
        from app.recommendations import DbRecommendationRepo

        hub.reco_repo = DbRecommendationRepo()
    except Exception as exc:  # DB 미기동 시 개발용 기본값(alice/bob)으로 동작
        logger.warning("DB unavailable, using dev defaults: %s", exc)
    sweeper = asyncio.create_task(hub.sweep_loop())
    yield
    sweeper.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await sweeper


app = FastAPI(title="IpMusic Backend", lifespan=lifespan)
app.include_router(ws_router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
