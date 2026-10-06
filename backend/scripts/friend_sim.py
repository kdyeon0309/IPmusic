"""친구 시뮬레이터 — 솔로 개발용.

bob(기본값)으로 WS에 접속해 now_playing을 보고한다. 실기기에서 alice로 앱을 켜면
노치에 bob 캐릭터가 등장하는지 검증하는 핵심 도구.

사용 예:
  uv run python scripts/friend_sim.py --track "밤편지" --artist "아이유"
  uv run python scripts/friend_sim.py --stop            # stopped 보고 후 종료
  uv run python scripts/friend_sim.py --listen          # 수신만 (상대편 역할 확인용)
  uv run python scripts/friend_sim.py --bubble "안녕!"   # 말풍선 전송 후 종료 (--to alice)
  uv run python scripts/friend_sim.py --recommend --track "Super Shy" --artist "NewJeans" --store-id 1694530913
  uv run python scripts/friend_sim.py --ack 3            # 추천 확인 보고
Ctrl+C로 종료하면 WS가 끊기며 서버가 즉시 퇴장 처리한다.
"""

import argparse
import asyncio
import contextlib
import json
from datetime import datetime, timezone

import websockets

HEARTBEAT_SECONDS = 30


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


async def listen(ws) -> None:
    async for raw in ws:
        print(f"<- {raw}")


async def run(args: argparse.Namespace) -> None:
    url = f"{args.url}/ws?user_id={args.user}"
    async with websockets.connect(url) as ws:
        print(f"connected as {args.user} -> {url}")
        listener = asyncio.create_task(listen(ws))
        try:
            if args.stop:
                await ws.send(json.dumps({"type": "stopped", "ts": now_iso()}))
                print("-> stopped")
                await asyncio.sleep(1)
                return
            if args.listen:
                await listener
                return
            if args.recommend:
                await ws.send(json.dumps(
                    {"type": "recommend", "to": args.to, "track": args.track,
                     "artist": args.artist, "store_id": args.store_id, "ts": now_iso()},
                    ensure_ascii=False,
                ))
                print(f"-> recommend to {args.to}: {args.track} — {args.artist} (store_id={args.store_id})")
                await asyncio.sleep(2)
                return
            if args.ack is not None:
                await ws.send(json.dumps(
                    {"type": "recommendation_ack", "recommendation_id": args.ack, "ts": now_iso()}
                ))
                print(f"-> recommendation_ack: {args.ack}")
                await asyncio.sleep(1)
                return
            if args.bubble:
                await ws.send(json.dumps(
                    {"type": "bubble", "to": args.to, "text": args.bubble, "ts": now_iso()},
                    ensure_ascii=False,
                ))
                print(f"-> bubble to {args.to}: {args.bubble}")
                await asyncio.sleep(2)  # 혹시 올 응답/push 출력 시간
                return
            report = {
                "type": "now_playing",
                "track": args.track,
                "artist": args.artist,
                "is_playing": True,
                "source": "apple_music",
                "ts": now_iso(),
            }
            while True:
                report["ts"] = now_iso()
                await ws.send(json.dumps(report, ensure_ascii=False))
                print(f"-> now_playing: {args.track} — {args.artist}")
                await asyncio.sleep(HEARTBEAT_SECONDS)
        finally:
            listener.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await listener


def main() -> None:
    parser = argparse.ArgumentParser(description="IpMusic 친구 시뮬레이터")
    parser.add_argument("--user", default="bob")
    parser.add_argument("--track", default="밤편지")
    parser.add_argument("--artist", default="아이유")
    parser.add_argument("--url", default="ws://localhost:8000")
    parser.add_argument("--stop", action="store_true", help="stopped 보고 후 종료")
    parser.add_argument("--listen", action="store_true", help="보고 없이 수신만")
    parser.add_argument("--bubble", help="말풍선 텍스트 전송 후 종료")
    parser.add_argument("--to", default="alice", help="말풍선/추천 수신자 (기본 alice)")
    parser.add_argument("--recommend", action="store_true", help="--track/--artist를 추천으로 전송 후 종료")
    parser.add_argument("--store-id", default="", help="애플뮤직 카탈로그 ID (추천용)")
    parser.add_argument("--ack", type=int, help="추천 확인(recommendation_ack) 전송 후 종료")
    args = parser.parse_args()
    with contextlib.suppress(KeyboardInterrupt):
        asyncio.run(run(args))


if __name__ == "__main__":
    main()
