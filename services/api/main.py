from __future__ import annotations

import logging
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from iiot_stack.logging_utils import configure_logging
from iiot_stack.settings import APISettings
from services.api.routers import alerts, assets, kpis, sites, stream, telemetry

LOG = logging.getLogger("api")

_STATIC_DIR = Path(__file__).parent / "static"


def create_app() -> FastAPI:
    settings = APISettings()
    configure_logging()

    app = FastAPI(
        title="NEXUS IIoT Platform API",
        description=(
            "REST + SSE API for the NEXUS IIoT Platform. "
            "Provides real-time asset status, telemetry history, alert management, and KPIs."
        ),
        version="1.0.0",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(assets.router)
    app.include_router(telemetry.router)
    app.include_router(alerts.router)
    app.include_router(kpis.router)
    app.include_router(sites.router)
    app.include_router(stream.router)

    @app.get("/health", tags=["health"])
    def health():
        return {"status": "ok"}

    # Serve compiled Svelte frontend — only if the build exists
    if _STATIC_DIR.exists():
        app.mount("/", StaticFiles(directory=str(_STATIC_DIR), html=True), name="static")
    else:
        LOG.info("static dir not found — frontend not served (run: cd frontend && npm run build)")

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    settings = APISettings()
    uvicorn.run(
        "services.api.main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=False,
        log_config=None,  # structured logging already configured
    )
