from fastapi import FastAPI

app = FastAPI(title="IpMusic Backend")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
