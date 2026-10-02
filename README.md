# CI/CD Pipeline and Kubernetes Deployment for a Microservice

[![CI/CD Pipeline](https://github.com/AswinArun321/microservice-cicd-kubernetes/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/AswinArun321/microservice-cicd-kubernetes/actions/workflows/ci-cd.yml)
[![Python 3.11](https://img.shields.io/badge/python-3.11-blue.svg)](https://www.python.org/downloads/)
[![Code Style: Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)
[![Tests: Pytest](https://img.shields.io/badge/tests-pytest-green.svg)](https://docs.pytest.org/)
[![Docker](https://img.shields.io/badge/docker-ready-2496ED.svg)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/kubernetes-orchestrated-326CE5.svg)](https://kubernetes.io/)

A containerized **3-service microservice application** with an automated CI/CD pipeline using **GitHub Actions** and production-style deployment to **Kubernetes**.

The project demonstrates how Docker, GitHub Actions, and Kubernetes are combined to automate application testing, code quality enforcement, container image creation, and rolling deployment with zero downtime.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Microservices Specifications](#microservices-specifications)
  - [1. Auth Service (Port 5001)](#1-auth-service-port-5001)
  - [2. API Service (Port 5002)](#2-api-service-port-5002)
  - [3. Worker Service (Port 5003)](#3-worker-service-port-5003)
- [Technologies Used](#technologies-used)
- [Project Directory Structure](#project-directory-structure)
- [Local Development & Testing](#local-development--testing)
  - [Local Environment Setup](#local-environment-setup)
  - [Running Unit Tests](#running-unit-tests)
  - [Code Linting with Ruff](#code-linting-with-ruff)
- [Docker & Containerization](#docker--containerization)
  - [Building Individual Docker Images](#building-individual-docker-images)
  - [Running with Docker Compose](#running-with-docker-compose)
  - [Verifying Container Health](#verifying-container-health)
- [CI/CD Pipeline with GitHub Actions](#cicd-pipeline-with-github-actions)
  - [Pipeline Flow](#pipeline-flow)
  - [Workflow Stages](#workflow-stages)
  - [Container Registry & Secrets](#container-registry--secrets)
- [Kubernetes Deployment](#kubernetes-deployment)
  - [Cluster Prerequisites (Minikube)](#cluster-prerequisites-minikube)
  - [Deploying Manifests](#deploying-manifests)
  - [Kubernetes Ingress & Routing](#kubernetes-ingress--routing)
  - [Rolling Updates & Zero Downtime](#rolling-updates--zero-downtime)
  - [Rollback Testing](#rollback-testing)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting Guide](#troubleshooting-guide)
- [Future Enhancements](#future-enhancements)
- [Author & License](#author--license)

---

## Project Overview

The application is decomposed into three decoupled microservices:

1. **Auth Service**: Manages user authentication, request validation, and cryptographic JWT token issuance and verification.
2. **API Service**: Serves core business APIs, statistical summaries, filtering, and data creation with Pydantic request/response models.
3. **Worker Service**: Simulates background task scheduling, asynchronous job processing, queue monitoring, and telemetry logging.

### Key Achievements

- **Single-command local environment** via Docker Compose (`docker compose up --build`).
- **Comprehensive test suite** with 23 passing unit tests across all services (`pytest`).
- **Strict code linting & formatting** with `ruff`.
- **Production-grade Dockerfiles** featuring lightweight base images (`python:3.11-slim`), non-root users (`UID 10001`), and built-in container health checks.
- **Automated CI/CD** executing checkout, dependency resolution, linting, unit testing, multi-arch Docker image compilation, and automated publishing to GitHub Container Registry (GHCR).
- **Kubernetes orchestration** with declarative Deployment, Service (ClusterIP), and Ingress manifests, complete with RollingUpdate strategies, Liveness/Readiness probes, and resource limits.

---

## Architecture

```text
                             Developer
                                |
                                | git push
                                v
                         GitHub Repository
                                |
                                v
                         GitHub Actions
                                |
             +------------------+------------------+
             |                                     |
             v                                     v
       Ruff Linter                           Pytest Suite
             |                                     |
             +------------------+------------------+
                                | (on pass)
                                v
                         Docker Buildx
                                |
                                v
                    GitHub Container Registry
                             (ghcr.io)
                                |
                                v
                       Kubernetes Cluster
                                |
                                v
                        Kubernetes Ingress
                                |
       +------------------------+------------------------+
       |                        |                        |
       v                        v                        v
  Auth Service             API Service             Worker Service
  (Port 5001)              (Port 5002)              (Port 5003)
  Replicas: 2              Replicas: 2              Replicas: 1
```

---

## Microservices Specifications

### 1. Auth Service (Port 5001)

Responsible for user authentication, payload validation, and JWT token lifecycle management.

- **Endpoints**:
  - `GET /health`: Health probe endpoint. Returns status, service name, and UTC timestamp.
  - `GET /`: Discovery endpoint with available service capabilities.
  - `POST /login`: Validates credentials (`username`, `password`) and issues signed HS256 JWT access token.
    - *Demo accounts*: `admin` / `admin123`, `developer` / `devpassword123`, `testuser` / `password123`.
  - `POST /verify`: Verifies JWT signature and returns claims or expiration status.

**Example Login Request**:
```bash
curl -X POST http://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}'
```

**Example Login Response**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsIn...",
  "token_type": "bearer",
  "username": "admin",
  "expires_in": 3600,
  "message": "Authentication successful"
}
```

---

### 2. API Service (Port 5002)

Provides the primary data and business operations.

- **Endpoints**:
  - `GET /health`: Health probe with service uptime metrics.
  - `GET /api/data`: Returns item records with optional `?category=` filter and `?limit=`.
  - `GET /api/data/{id}`: Returns details of a single record (or 404 Not Found).
  - `POST /api/data`: Validates and creates a new data record (201 Created).
  - `GET /api/stats`: Aggregates total records and category distributions.

**Example Data Fetch**:
```bash
curl http://localhost:5002/api/data?category=devops
```

---

### 3. Worker Service (Port 5003)

Manages background task execution, telemetry, and periodic maintenance.

- **Endpoints**:
  - `GET /health`: Liveness probe indicating worker health and total processed jobs.
  - `GET /status`: Detailed worker telemetry, queue parameters, and history of recent tasks.
  - `POST /jobs`: Enqueues and executes an on-demand task simulation.

**Example Worker Status**:
```bash
curl http://localhost:5003/status
```

---

## Technologies Used

| Technology | Purpose |
|---|---|
| **Python 3.11** | Backend application programming language |
| **FastAPI** | High-performance, async web framework |
| **Pydantic v2** | Strong schema validation and serialization |
| **PyJWT** | JSON Web Token encoding and verification |
| **Uvicorn** | ASGI production server |
| **Ruff** | Lightning-fast Python linter and code quality validator |
| **Pytest** | Test suite runner for unit and integration testing |
| **Docker** | Containerization engine |
| **Docker Compose** | Multi-container local orchestration |
| **GitHub Actions** | Automated CI/CD pipeline execution |
| **GHCR (GitHub Container Registry)** | OCI-compliant container image registry |
| **Kubernetes** | Production container orchestration platform |
| **Minikube** | Local Kubernetes cluster environment |
| **Ingress (NGINX)** | Path-based HTTP reverse proxy and ingress routing |

---

## Project Directory Structure

```text
microservice-cicd-kubernetes/
│
├── auth/                               # Auth Microservice
│   ├── app/
│   │   ├── __init__.py
│   │   └── main.py                     # FastAPI application with JWT & auth logic
│   ├── tests/
│   │   └── test_auth.py                # Pytest unit tests (8 tests)
│   ├── requirements.txt                # Auth service dependencies
│   └── Dockerfile                      # Multi-stage non-root container definition
│
├── api/                                # Core API Microservice
│   ├── app/
│   │   ├── __init__.py
│   │   └── main.py                     # FastAPI application with business logic
│   ├── tests/
│   │   └── test_api.py                 # Pytest unit tests (9 tests)
│   ├── requirements.txt                # API service dependencies
│   └── Dockerfile                      # Multi-stage non-root container definition
│
├── worker/                             # Worker Microservice
│   ├── app/
│   │   ├── __init__.py
│   │   └── main.py                     # Background worker loop & telemetry
│   ├── tests/
│   │   └── test_worker.py              # Pytest unit tests (6 tests)
│   ├── requirements.txt                # Worker service dependencies
│   └── Dockerfile                      # Multi-stage non-root container definition
│
├── k8s/                                # Kubernetes Manifests
│   ├── auth-deployment.yaml            # Replicas, rolling update, probes, security
│   ├── auth-service.yaml               # ClusterIP service for auth
│   ├── api-deployment.yaml             # Replicas, rolling update, probes, security
│   ├── api-service.yaml                # ClusterIP service for api
│   ├── worker-deployment.yaml          # Deployment for background worker
│   ├── worker-service.yaml             # ClusterIP service for worker
│   └── ingress.yaml                    # NGINX Ingress path-based routing
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml                   # Automated lint, test, build, push pipeline
│
├── docker-compose.yml                  # Local development orchestration
├── pyproject.toml                      # Tooling configuration for pytest and ruff
├── requirements.txt                    # Root dependencies for development
├── .gitignore                          # Excludes venvs, caches, logs, credentials
├── README.md                           # Complete project documentation
└── plan.md                             # Step-by-step master implementation plan
```

---

## Local Development & Testing

### Local Environment Setup

1. **Clone repository**:
   ```bash
   git clone https://github.com/AswinArun321/microservice-cicd-kubernetes.git
   cd microservice-cicd-kubernetes
   ```

2. **Create and activate virtual environment**:
   ```bash
   python -m venv venv
   # On Windows:
   .\venv\Scripts\activate
   # On Linux/macOS:
   source venv/bin/activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

### Running Unit Tests

Run the complete test suite across all three microservices:

```bash
pytest -v
```

Expected result:
```text
auth/tests/test_auth.py::test_health_endpoint PASSED
auth/tests/test_auth.py::test_root_endpoint PASSED
auth/tests/test_auth.py::test_login_successful PASSED
auth/tests/test_auth.py::test_login_invalid_password PASSED
auth/tests/test_auth.py::test_login_unknown_user PASSED
auth/tests/test_auth.py::test_login_validation_error PASSED
auth/tests/test_auth.py::test_verify_valid_token PASSED
auth/tests/test_auth.py::test_verify_invalid_token PASSED
api/tests/test_api.py::test_health_endpoint PASSED
api/tests/test_api.py::test_root_endpoint PASSED
api/tests/test_api.py::test_get_all_data PASSED
api/tests/test_api.py::test_get_data_with_category_filter PASSED
api/tests/test_api.py::test_get_data_item_by_id_success PASSED
api/tests/test_api.py::test_get_data_item_by_id_not_found PASSED
api/tests/test_api.py::test_create_data_item_success PASSED
api/tests/test_api.py::test_create_data_item_validation_error PASSED
api/tests/test_api.py::test_get_stats PASSED
worker/tests/test_worker.py::test_health_endpoint PASSED
worker/tests/test_worker.py::test_root_endpoint PASSED
worker/tests/test_worker.py::test_worker_status_endpoint PASSED
worker/tests/test_worker.py::test_enqueue_job_success PASSED
worker/tests/test_worker.py::test_enqueue_job_validation_error PASSED
worker/tests/test_worker.py::test_process_single_job_logic PASSED

======================== 23 passed in 0.99s ========================
```

### Code Linting with Ruff

Ensure all code satisfies strict PEP8, import sorting, and syntax rules:

```bash
ruff check .
```

---

## Docker & Containerization

### Building Individual Docker Images

Each microservice contains a self-contained Dockerfile:

```bash
# Build Auth Service image
docker build -t auth-service ./auth

# Build API Service image
docker build -t api-service ./api

# Build Worker Service image
docker build -t worker-service ./worker
```

### Running with Docker Compose

Launch the entire microservice ecosystem with a single command:

```bash
# Build and start all services in detached mode
docker compose up -d --build
```

Check running containers:
```bash
docker compose ps
```

View real-time aggregated logs:
```bash
docker compose logs -f
```

Stop and clean up containers:
```bash
docker compose down
```

### Verifying Container Health

Once running, verify all three services:

```bash
# Auth Service Health
curl http://localhost:5001/health

# API Service Health
curl http://localhost:5002/health

# Worker Service Health
curl http://localhost:5003/health
```

---

## CI/CD Pipeline with GitHub Actions

The automated pipeline is defined in [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml).

### Pipeline Flow

```text
git push / pull_request (to main or master)
         |
         +-----------------------+
         |                       |
         v                       v
     [Job 1: Lint]          [Job 2: Test]
     - Setup Python 3.11    - Setup Python 3.11
     - Cache pip            - Cache pip
     - ruff check .         - pytest -v
         |                       |
         +-----------+-----------+
                     | (needs: [lint, test])
                     v
            [Job 3: Build & Push]
            - Matrix: [auth, api, worker]
            - Docker Buildx Setup
            - Login to ghcr.io (GITHUB_TOKEN)
            - Docker build
            - Docker push with :latest and :<sha>
```

### Container Registry & Secrets

Images are published to **GitHub Container Registry (GHCR)**:
- `ghcr.io/aswinarun321/auth-service`
- `ghcr.io/aswinarun321/api-service`
- `ghcr.io/aswinarun321/worker-service`

No hardcoded secrets are present in the repository. The workflow uses the standard, automatically provisioned `GITHUB_TOKEN` with `packages: write` permissions.

---

## Kubernetes Deployment

### Cluster Prerequisites (Minikube)

1. Start your local Minikube cluster:
   ```bash
   minikube start
   ```

2. Enable the Ingress addon:
   ```bash
   minikube addons enable ingress
   ```

3. Confirm cluster readiness:
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

### Deploying Manifests

Apply all manifests in the [`k8s/`](k8s/) directory:

```bash
kubectl apply -f k8s/
```

Verify deployment status:

```bash
# Verify Pods
kubectl get pods

# Verify Deployments
kubectl get deployments

# Verify ClusterIP Services
kubectl get services

# Verify Ingress
kubectl get ingress
```

Expected output:
```text
NAME                                 READY   STATUS    RESTARTS   AGE
pod/auth-deployment-5c689d5f7b-2k4m8 1/1     Running   0          45s
pod/auth-deployment-5c689d5f7b-9x2pl 1/1     Running   0          45s
pod/api-deployment-7f94bb6c9d-8j2k1  1/1     Running   0          45s
pod/api-deployment-7f94bb6c9d-w4q9z  1/1     Running   0          45s
pod/worker-deployment-647d68b6-q7p8x 1/1     Running   0          45s
```

### Kubernetes Ingress & Routing

The [`k8s/ingress.yaml`](k8s/ingress.yaml) configuration routes traffic through a single entry point:

```text
                        Minikube Ingress (Port 80)
                                     |
           +-------------------------+-------------------------+
           |                         |                         |
           v                         v                         v
     Path: /auth               Path: /api               Path: /worker
           |                         |                         |
           v                         v                         v
      auth-service               api-service             worker-service
       Port: 5001                Port: 5002                Port: 5003
```

To access the cluster via Minikube:
```bash
minikube ip
```

Add the Minikube IP or test directly:
```bash
MINIKUBE_IP=$(minikube ip)
curl http://$MINIKUBE_IP/auth/health
curl http://$MINIKUBE_IP/api/health
curl http://$MINIKUBE_IP/worker/health
```

### Rolling Updates & Zero Downtime

All deployments use a zero-downtime rolling update strategy:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

To deploy a new version:
```bash
kubectl set image deployment/api-deployment api-service=ghcr.io/aswinarun321/api-service:v2.0.0
```

Monitor the rollout progress in real time:
```bash
kubectl rollout status deployment/api-deployment
```

### Rollback Testing

If an issue occurs in a newly deployed revision, Kubernetes allows instant rollbacks:

1. Check rollout revision history:
   ```bash
   kubectl rollout history deployment/api-deployment
   ```

2. Rollback to the previous stable release:
   ```bash
   kubectl rollout undo deployment/api-deployment
   ```

3. Confirm rollback status:
   ```bash
   kubectl rollout status deployment/api-deployment
   ```

---

## Security Best Practices

This project adheres to cloud-native security standards:

- **Non-Root Execution**: Containers do not run as root. Both Dockerfiles and Kubernetes manifests enforce `USER 10001` (`runAsNonRoot: true`).
- **Privilege Escalation Prevention**: Kubernetes pods configure `allowPrivilegeEscalation: false` and drop all Linux capabilities (`capabilities: drop: ["ALL"]`).
- **Zero Hardcoded Secrets**: Secrets and tokens are not committed to Git. `.gitignore` prevents tracking `.env` or sensitive files.
- **Resource Containment**: CPU and Memory requests and limits are defined on all containers to prevent noisy-neighbor syndrome or denial of service.
- **Health & Liveness Probes**: Automatic detection and recovery from deadlocks or application failure via HTTP probes.

---

## Troubleshooting Guide

| Issue | Cause | Resolution |
|---|---|---|
| `CrashLoopBackOff` | Application failed to start or health probe failed | Check logs with `kubectl logs <pod-name>` or verify probe endpoint. |
| `ImagePullBackOff` / `ErrImagePull` | Registry image does not exist or credentials missing | Check image name and tag in `k8s/*-deployment.yaml`. For local testing, run `eval $(minikube docker-env)` before building. |
| `Pending` Pods | Insufficient CPU/Memory on cluster node | Inspect node capacity with `kubectl describe nodes` and adjust requests/limits in manifests. |
| Ingress 404 / 503 | Ingress controller not enabled or service selector mismatch | Run `minikube addons enable ingress` and ensure `spec.selector` in Service matches Deployment labels. |

---

## Future Enhancements

- [ ] Automated image vulnerability scanning with Trivy in CI.
- [ ] Helm Chart packaging for single-command chart deployments.
- [ ] Horizontal Pod Autoscaling (HPA) based on CPU/Memory load metrics.
- [ ] Prometheus metrics collection and Grafana observability dashboards.
- [ ] Terraform IaC scripts for provisioning AWS EKS clusters.

---

## Author & License

**Aswin Arunkumar A**  
MSc Computer Science (Data Analytics)  
Rajagiri College of Social Sciences  
GitHub: [@AswinArun321](https://github.com/AswinArun321)

This project is licensed under the MIT License — created for educational and portfolio demonstration.
