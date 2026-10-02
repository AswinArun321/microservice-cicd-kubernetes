"""Unit tests for API Service."""

from fastapi.testclient import TestClient

try:
    from api.app.main import app
except ModuleNotFoundError:
    from app.main import app

client = TestClient(app)


def test_health_endpoint():
    """Verify that the /health endpoint responds with 200 and healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "api-service"
    assert "uptime_seconds" in data


def test_root_endpoint():
    """Verify root discovery endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert "/api/data" in data["endpoints"]


def test_get_all_data():
    """Verify retrieval of data items."""
    response = client.get("/api/data")
    assert response.status_code == 200
    items = response.json()
    assert isinstance(items, list)
    assert len(items) >= 4


def test_get_data_with_category_filter():
    """Verify filtering by category."""
    response = client.get("/api/data?category=devops")
    assert response.status_code == 200
    items = response.json()
    assert len(items) >= 1
    for item in items:
        assert item["category"].lower() == "devops"


def test_get_data_item_by_id_success():
    """Verify retrieving an existing item by ID."""
    response = client.get("/api/data/1")
    assert response.status_code == 200
    item = response.json()
    assert item["id"] == 1
    assert "title" in item


def test_get_data_item_by_id_not_found():
    """Verify 404 for non-existent item ID."""
    response = client.get("/api/data/99999")
    assert response.status_code == 404
    assert "not found" in response.json()["detail"].lower()


def test_create_data_item_success():
    """Verify creating a new valid data item."""
    payload = {
        "title": "Automated Chaos Engineering Test",
        "category": "reliability",
        "value": 91.5,
        "description": "Simulating pod failures in k8s cluster",
    }
    response = client.post("/api/data", json=payload)
    assert response.status_code == 201
    created = response.json()
    assert created["title"] == payload["title"]
    assert created["category"] == payload["category"]
    assert created["value"] == 91.5
    assert created["status"] == "active"
    assert "id" in created


def test_create_data_item_validation_error():
    """Verify validation error when required fields are missing or invalid."""
    payload = {
        "title": "ab",  # too short (< 3)
        "category": "a",  # too short (< 2)
        "value": -10.0,  # negative value (invalid, ge=0.0)
    }
    response = client.post("/api/data", json=payload)
    assert response.status_code == 422


def test_get_stats():
    """Verify statistical summary endpoint."""
    response = client.get("/api/stats")
    assert response.status_code == 200
    data = response.json()
    assert "total_items" in data
    assert "categories" in data
    assert data["service"] == "api-service"
