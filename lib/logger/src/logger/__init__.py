from loguru import logger
import sys
from pathlib import Path

def setup_logger(log_file: str = "logs/app.log"):
    Path(log_file).parent.mkdir(parents=True, exist_ok=True)

    logger.remove()

    logger.add(sys.stdout, level="INFO", format="<green>{time}</green> | <level>{level}</level> | <cyan>{message}</cyan>")

    logger.add(
        log_file,
        rotation="5 MB",
        retention=5,
        level="DEBUG",
        format="{time} | {level} | {message}"
    )

    return logger

__all__ = ["setup_logger"]