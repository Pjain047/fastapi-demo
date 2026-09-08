import logging
import sys
from pythonjsonlogger import jsonlogger
from app.config import get_settings
from datetime import UTC, datetime

settings = get_settings()

class ApplicationJsonFormatter(jsonlogger.JsonFormatter):
    """
    Custom JSON formatter for application logs.
    """

    def add_fields(self, log_record, record, message_dict):
        super().add_fields(log_record, record, message_dict)
        settings = get_settings()

        log_record["timestamp"] = datetime.now(UTC).isoformat()
        log_record["level"] = record.levelname
        log_record["logger"] = record.name
        log_record["application"] = settings.app_name
        log_record["environment"] = settings.environment

        log_record.pop("asctime", None)
        log_record.pop("levelname", None)
        log_record.pop("name", None)

def configure_logging() -> None:
    """
    Configure logging for the application.
    """
    logger = logging.getLogger()
    logger.setLevel(settings.log_level.upper())
    logger.handlers.clear()

    handler = logging.StreamHandler(sys.stdout)

    formatter = ApplicationJsonFormatter("%(message)s")

    handler.setFormatter(formatter)
    logger.addHandler(handler)

def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance with the specified name.
    """
    return logging.getLogger(name)
