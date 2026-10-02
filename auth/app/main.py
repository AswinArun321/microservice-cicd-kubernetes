"""Auth Service - Microservice handling user authentication and token issuance."""

import os
from datetime import datetime, timedelta, timezone
from typing import Optional

import jwt
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field

# Configuration
SERVICE_NAME = os.getenv("SERVICE_NAME", "auth-service")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.0.0")
JWT_SECRET = os.getenv("JWT_SECRET", "microservice-super-secret-key-321")
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_MINUTES = int(os.getenv("JWT_EXPIRATION_MINUTES", "60"))
PORT = int(os.getenv("PORT", "5001"))

# Demo User Database
DEMO_USERS = {
    "admin": "admin123",
    "developer": "devpassword123",
    "testuser": "password123",
}

app = FastAPI(
    title="Auth Microservice",
    description="Authentication and token management microservice",
    version=SERVICE_VERSION,
)


class LoginRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50, description="Username")
    password: str = Field(..., min_length=6, max_length=100, description="Password")


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    username: str
    expires_in: int
    message: str


class TokenVerifyRequest(BaseModel):
    token: str


class TokenVerifyResponse(BaseModel):
    valid: bool
    username: Optional[str] = None
    expires_at: Optional[str] = None
    detail: Optional[str] = None


@app.get("/")
def read_root():
    return {
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "status": "online",
        "endpoints": ["/health", "/login", "/verify"],
    }


@app.get("/health")
def health_check():
    """Health check endpoint for Kubernetes liveness & readiness probes."""
    return {
        "status": "healthy",
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/login", response_model=LoginResponse)
def login(request: LoginRequest):
    """Authenticate user credentials and return a signed JWT token."""
    username = request.username
    password = request.password

    # Validate against demo credentials
    stored_password = DEMO_USERS.get(username)
    if stored_password is None or stored_password != password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Issue JWT token
    now = datetime.now(timezone.utc)
    expiration = now + timedelta(minutes=JWT_EXPIRATION_MINUTES)
    payload = {
        "sub": username,
        "iss": SERVICE_NAME,
        "iat": int(now.timestamp()),
        "exp": int(expiration.timestamp()),
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

    return LoginResponse(
        access_token=token,
        token_type="bearer",
        username=username,
        expires_in=JWT_EXPIRATION_MINUTES * 60,
        message="Authentication successful",
    )


@app.post("/verify", response_model=TokenVerifyResponse)
def verify_token(request: TokenVerifyRequest):
    """Validate a signed JWT token."""
    try:
        payload = jwt.decode(request.token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        exp_ts = payload.get("exp")
        exp_iso = (
            datetime.fromtimestamp(exp_ts, tz=timezone.utc).isoformat()
            if exp_ts
            else None
        )
        return TokenVerifyResponse(
            valid=True,
            username=payload.get("sub"),
            expires_at=exp_iso,
            detail="Token is valid",
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token signature or payload",
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=PORT, reload=True)
