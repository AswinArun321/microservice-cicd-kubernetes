"""API Service - Core microservice serving business data and APIs."""

import os
from datetime import datetime, timezone
from typing import Dict, List, Optional

from fastapi import FastAPI, HTTPException, Query, status
from pydantic import BaseModel, Field

# Configuration
SERVICE_NAME = os.getenv("SERVICE_NAME", "api-service")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.0.0")
PORT = int(os.getenv("PORT", "5002"))

app = FastAPI(
    title="Core API Microservice",
    description="Business logic and data processing microservice",
    version=SERVICE_VERSION,
)

# Start time for uptime calculation
START_TIME = datetime.now(timezone.utc)

# Initial sample dataset
INITIAL_DATA: List[Dict] = [
    {
        "id": 1,
        "title": "Cloud Migration Architecture",
        "category": "infrastructure",
        "value": 94.5,
        "status": "completed",
        "created_at": "2026-01-15T08:00:00Z",
    },
    {
        "id": 2,
        "title": "Kubernetes Ingress Controller Setup",
        "category": "networking",
        "value": 88.0,
        "status": "completed",
        "created_at": "2026-02-10T11:30:00Z",
    },
    {
        "id": 3,
        "title": "Automated CI/CD Pipeline Deployment",
        "category": "devops",
        "value": 99.2,
        "status": "active",
        "created_at": "2026-03-01T14:15:00Z",
    },
    {
        "id": 4,
        "title": "Microservice Distributed Tracing",
        "category": "observability",
        "value": 78.4,
        "status": "in_progress",
        "created_at": "2026-03-20T09:45:00Z",
    },
]

# In-memory storage seeded with sample data
data_store: List[Dict] = [dict(item) for item in INITIAL_DATA]
next_id: int = len(data_store) + 1


class DataItemCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=100, description="Title of the item")
    category: str = Field(..., min_length=2, max_length=50, description="Category")
    value: float = Field(..., ge=0.0, description="Numerical metric value")
    description: Optional[str] = Field(None, max_length=255, description="Optional description")


class DataItem(BaseModel):
    id: int
    title: str
    category: str
    value: float
    status: str
    created_at: str
    description: Optional[str] = None


@app.get("/")
def read_root():
    return {
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "status": "online",
        "endpoints": ["/health", "/api/data", "/api/stats"],
    }


@app.get("/health")
def health_check():
    """Health check endpoint for Kubernetes liveness & readiness probes."""
    return {
        "status": "healthy",
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "uptime_seconds": (datetime.now(timezone.utc) - START_TIME).total_seconds(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/api/data", response_model=List[DataItem])
@app.get("/data", response_model=List[DataItem], include_in_schema=False)
def get_data(
    category: Optional[str] = Query(None, description="Filter items by category"),
    limit: int = Query(50, ge=1, le=100, description="Max items to return"),
):
    """Retrieve items from the dataset with optional filtering."""
    results = data_store
    if category:
        results = [item for item in results if item["category"].lower() == category.lower()]
    return results[:limit]


@app.get("/api/data/{item_id}", response_model=DataItem)
@app.get("/data/{item_id}", response_model=DataItem, include_in_schema=False)
def get_data_item(item_id: int):
    """Retrieve a single item by ID."""
    for item in data_store:
        if item["id"] == item_id:
            return item
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"Data item with id {item_id} not found",
    )


@app.post("/api/data", response_model=DataItem, status_code=status.HTTP_201_CREATED)
@app.post(
    "/data",
    response_model=DataItem,
    status_code=status.HTTP_201_CREATED,
    include_in_schema=False,
)
def create_data_item(item_in: DataItemCreate):
    """Create and insert a new data item into the store."""
    global next_id
    new_item = {
        "id": next_id,
        "title": item_in.title,
        "category": item_in.category,
        "value": item_in.value,
        "description": item_in.description,
        "status": "active",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    data_store.append(new_item)
    next_id += 1
    return new_item


@app.get("/api/stats")
@app.get("/stats", include_in_schema=False)
def get_stats():
    """Return statistical summary of stored data."""
    categories: Dict[str, int] = {}
    for item in data_store:
        cat = item["category"]
        categories[cat] = categories.get(cat, 0) + 1

    return {
        "total_items": len(data_store),
        "categories": categories,
        "service": SERVICE_NAME,
        "uptime_seconds": (datetime.now(timezone.utc) - START_TIME).total_seconds(),
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=PORT, reload=True)
