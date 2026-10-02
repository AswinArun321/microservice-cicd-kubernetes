"""Unit tests for Worker Service."""

import os

from fastapi.testclient import TestClient

# Disable auto-starting background infinite loop during test execution
os.environ["AUTO_START_WORKER"] = "false"

try:
    from worker.app.main import app, process_single_job
except ModuleNotFoundError:
    from app.main import app, process_single_job

client = TestClient(app)


def test_health_endpoint():
    """Verify that /health responds with 200 and healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "worker-service"
    assert "jobs_processed" in data
    assert "timestamp" in data


def test_root_endpoint():
    """Verify root discovery endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert "/status" in data["endpoints"]


def test_worker_status_endpoint():
    """Verify /status endpoint returns detailed telemetry."""
    response = client.get("/status")
    assert response.status_code == 200
    data = response.json()
    assert "total_jobs_processed" in data
    assert "recent_jobs" in data
    assert data["service"] == "worker-service"


def test_enqueue_job_success():
    """Verify manual job enqueueing via POST /jobs."""
    payload = {
        "task_type": "email_notification_batch",
        "payload": {"recipient_count": 50, "template": "weekly_digest"},
    }
    response = client.post("/jobs", json=payload)
    assert response.status_code == 202
    data = response.json()
    assert "job" in data
    assert data["job"]["task_type"] == "email_notification_batch"
    assert data["job"]["status"] == "completed"
    assert data["job"]["job_number"] > 0


def test_enqueue_job_validation_error():
    """Verify validation error when task_type is invalid."""
    payload = {
        "task_type": "ab",  # too short (< 3)
    }
    response = client.post("/jobs", json=payload)
    assert response.status_code == 422


def test_process_single_job_logic():
    """Direct test of the job execution simulator function."""
    record = process_single_job(task_type="test_direct_execution", payload={"key": "value"})
    assert record["status"] == "completed"
    assert record["task_type"] == "test_direct_execution"
    assert "job_id" in record
    assert record["payload"]["key"] == "value"
