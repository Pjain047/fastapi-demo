import time
from collections.abc import Awaitable, Callable
from uuid import uuid4

from fastapi import Request, Response
from app.logger import get_logger

logger = get_logger(__name__)

CORRELATION_ID_HEADER = "X-Correlation-ID"
PROCESSING_TIME_HEADER = "X-Processing-Time"

async def request_logging_middleware(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    start_time = time.time()
    correlation_id = request.headers.get(CORRELATION_ID_HEADER, str(uuid4()))

    request.state.correlation_id = correlation_id

    client_ip = request.client.host if request.client else "unknown"

    logger.info(
        "Request Started",
        extra={
            "event": "http_request_started",
            "correlation_id": correlation_id,
            "http_method": request.method,
            "path": request.url.path,
            "query_params": request.url.query or None,
                "client_ip": client_ip,
        },
    )

    try:
        response = await call_next(request)

    except Exception as exc:
        duration_ms = round((time.time() - start_time) * 1000, 2)

        logger.exception(
            "Request Failed with an exception",
            extra={
                "event": "http_request_failed",
                "correlation_id": correlation_id,
                "http_method": request.method,
                "path": request.url.path,
                "query_params": request.url.query or None,
                "client_ip": client_ip,
                "duration_ms": duration_ms,
                "exception": str(exc),
            },
        )

        raise

    duration_ms = round((time.time() - start_time) * 1000, 2)

    response.headers[CORRELATION_ID_HEADER] = correlation_id
    response.headers[PROCESSING_TIME_HEADER] = str(duration_ms)

    logger.info(
        "Request Completed",
        extra={
            "event": "http_request_completed",
            "correlation_id": correlation_id,
            "http_method": request.method,
            "path": request.url.path,
            "query_params": request.url.query or None,
            "client_ip": client_ip,
            "duration_ms": duration_ms,
        },
    )

    return response