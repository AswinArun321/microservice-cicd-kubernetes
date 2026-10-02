"""Unit tests for Auth Service."""

from fastapi.testclient import TestClient

try:
    from auth.app.main import app
except ModuleNotFoundError:
    from app.main import app

client = TestClient(app)


def test_health_endpoint():
    """Verify that the /health endpoint responds with 200 and healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "auth-service"
    assert "timestamp" in data


def test_root_endpoint():
    """Verify the root metadata endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert "/health" in data["endpoints"]


def test_login_successful():
    """Verify that valid credentials return an access token."""
    payload = {
        "username": "admin",
        "password": "admin123",
    }
    response = client.post("/login", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["username"] == "admin"
    assert data["expires_in"] > 0


def test_login_invalid_password():
    """Verify that incorrect credentials return 401 Unauthorized."""
    payload = {
        "username": "admin",
        "password": "wrongpassword999",
    }
    response = client.post("/login", json=payload)
    assert response.status_code == 401
    assert "Invalid username or password" in response.json()["detail"]


def test_login_unknown_user():
    """Verify that nonexistent username returns 401 Unauthorized."""
    payload = {
        "username": "nonexistent_user",
        "password": "somepassword123",
    }
    response = client.post("/login", json=payload)
    assert response.status_code == 401


def test_login_validation_error():
    """Verify that invalid/short input triggers validation error (HTTP 422)."""
    # password too short (less than 6 chars)
    payload = {
        "username": "ad",
        "password": "12",
    }
    response = client.post("/login", json=payload)
    assert response.status_code == 422


def test_verify_valid_token():
    """Verify that a valid token can be successfully verified."""
    login_resp = client.post(
        "/login",
        json={"username": "testuser", "password": "password123"},
    )
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]

    verify_resp = client.post("/verify", json={"token": token})
    assert verify_resp.status_code == 200
    data = verify_resp.json()
    assert data["valid"] is True
    assert data["username"] == "testuser"


def test_verify_invalid_token():
    """Verify that an invalid token signature returns 401 Unauthorized."""
    verify_resp = client.post("/verify", json={"token": "invalid.jwt.token.string"})
    assert verify_resp.status_code == 401
