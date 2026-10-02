"""Worker Service - Background job processing microservice."""

import asyncio
import logging
import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Dict, List, Optional

from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [worker-service]: %(message)s",
)
logger = logging.getLogger("worker")

# Configuration
SERVICE_NAME = os.getenv("SERVICE_NAME", "worker-service")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.0.0")
PORT = int(os.getenv("PORT", "5003"))
WORKER_INTERVAL = float(os.getenv("WORKER_INTERVAL", "5.0"))
AUTO_START_WORKER = os.getenv("AUTO_START_WORKER", "true").lower() in ("true", "1", "yes")

# Service state
START_TIME = datetime.now(timezone.utc)
processed_jobs: List[Dict] = []
job_counter: int = 0
is_worker_running: bool = False
worker_task: Optional[asyncio.Task] = None


def process_single_job(task_type: str = "periodic_sync", payload: Optional[Dict] = None) -> Dict:
    """Simulate execution of a background task."""
    global job_counter
    job_counter += 1
    job_id = f"job-{uuid.uuid4().hex[:8]}"
    start = datetime.now(timezone.utc)

    # Simulated processing metrics
    record = {
        "job_id": job_id,
        "job_number": job_counter,
        "task_type": task_type,
        "status": "completed",
        "processed_at": start.isoformat(),
        "duration_ms": 25.4,
        "payload": payload or {"action": "heartbeat_sync"},
    }

    # Keep only the last 20 jobs in history
    processed_jobs.append(record)
    if len(processed_jobs) > 20:
        processed_jobs.pop(0)

    logger.info("Processed job %s [%s] successfully (#%d)", job_id, task_type, job_counter)
    return record


async def worker_loop():
    """Continuous background loop processing asynchronous tasks."""
    global is_worker_running
    is_worker_running = True
    logger.info("Background worker loop started with interval of %s seconds.", WORKER_INTERVAL)
    try:
        while True:
            await asyncio.sleep(WORKER_INTERVAL)
            process_single_job(task_type="scheduled_maintenance")
    except asyncio.CancelledError:
        logger.info("Background worker loop cancelled gracefully.")
    finally:
        is_worker_running = False


@asynccontextmanager
async def lifespan(app: FastAPI):
    """FastAPI lifespan to manage background task lifecycle."""
    global worker_task
    if AUTO_START_WORKER:
        worker_task = asyncio.create_task(worker_loop())
    yield
    if worker_task and not worker_task.done():
        worker_task.cancel()
        try:
            await worker_task
        except asyncio.CancelledError:
            pass


app = FastAPI(
    title="Worker Microservice",
    description="Background processing and queue simulation microservice",
    version=SERVICE_VERSION,
    lifespan=lifespan,
)


class EnqueueJobRequest(BaseModel):
    task_type: str = Field(..., min_length=3, max_length=50, description="Type of background job")
    payload: Optional[Dict] = Field(None, description="Optional job payload")


@app.get("/")
def read_root():
    return {
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "status": "online",
        "endpoints": ["/health", "/status", "/jobs"],
    }


@app.get("/health")
def health_check():
    """Health check endpoint for Kubernetes liveness & readiness probes."""
    return {
        "status": "healthy",
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "jobs_processed": job_counter,
        "uptime_seconds": (datetime.now(timezone.utc) - START_TIME).total_seconds(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/status")
def get_worker_status():
    """Return detailed worker telemetry and recent task history."""
    return {
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "worker_running": is_worker_running,
        "interval_seconds": WORKER_INTERVAL,
        "total_jobs_processed": job_counter,
        "recent_jobs": list(reversed(processed_jobs[-10:])),
        "uptime_seconds": (datetime.now(timezone.utc) - START_TIME).total_seconds(),
    }


@app.post("/jobs", status_code=status.HTTP_202_ACCEPTED)
def enqueue_job(request: EnqueueJobRequest):
    """Manually trigger/enqueue a background job."""
    if not request.task_type:
        raise HTTPException(status_code=400, detail="task_type must be provided")

    result = process_single_job(task_type=request.task_type, payload=request.payload)
    return {
        "message": "Job accepted and processed",
        "job": result,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=PORT, reload=True)
