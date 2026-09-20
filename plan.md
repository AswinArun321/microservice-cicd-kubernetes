# CI/CD Pipeline and Kubernetes Deployment for a Microservice

## 1. Project Objective

Build a production-style 3-service microservice application and create an automated CI/CD pipeline for it.

The final project should demonstrate:

- Microservice architecture
- Three independent services
- Docker containerization
- Docker Compose for local development
- Automated CI using GitHub Actions
- Linting
- Unit testing
- Docker image building
- Docker image publishing
- Kubernetes deployment
- Kubernetes Deployments
- Kubernetes Services
- Kubernetes Ingress
- Rolling updates
- Local Kubernetes deployment using Minikube
- Optional deployment to AWS EKS

### Target Architecture

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
              +-------------+-------------+
              |             |             |
              v             v             v
            Lint        Unit Tests    Docker Build
                                          |
                                          v
                                  Container Registry
                                          |
                                          v
                                    Kubernetes
                                          |
                 +------------------------+------------------------+
                 |                        |                        |
                 v                        v                        v
           Auth Service             API Service             Worker Service
                 |                        |                        |
                 +------------------------+------------------------+
                                          |
                                          v
                                      Ingress
```

---

# 2. Project Requirements

## 2.1 Functional Requirements

The application must contain three services:

### Auth Service

Responsible for authentication-related functionality.

Minimum functionality:

- Health endpoint
- Login/authentication endpoint
- Basic request validation
- Unit tests

Example:

```text
GET /health
POST /login
```

---

### API Service

Responsible for the main application/API functionality.

Minimum functionality:

- Health endpoint
- Example API endpoint
- Request handling
- Unit tests

Example:

```text
GET /health
GET /api/data
```

---

### Worker Service

Responsible for background processing.

Minimum functionality:

- Health/status functionality
- Background task simulation
- Logging
- Unit tests

Example:

```text
GET /health
```

The exact business functionality can remain simple because the primary objective is demonstrating **containerization, CI/CD, and Kubernetes deployment**.

---

# 3. Technology Stack

Use the following stack:

```text
Backend:
    Python

Containerization:
    Docker
    Docker Compose

CI/CD:
    GitHub Actions

Container Registry:
    GitHub Container Registry or Docker Hub

Orchestration:
    Kubernetes

Local Kubernetes:
    Minikube

Kubernetes Tools:
    kubectl

Optional Cloud:
    AWS EKS
```

---

# 4. Development Environment

Install the following tools:

- Git
- Python
- Docker Desktop
- kubectl
- Minikube
- GitHub account

Verify:

```bash
git --version
python --version
docker --version
kubectl version --client
minikube version
```

---

# 5. Create Project Structure

Create:

```text
microservice-cicd-kubernetes/
│
├── auth/
│   ├── app/
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
│
├── api/
│   ├── app/
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
│
├── worker/
│   ├── app/
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
│
├── k8s/
│   ├── auth-deployment.yaml
│   ├── auth-service.yaml
│   ├── api-deployment.yaml
│   ├── api-service.yaml
│   ├── worker-deployment.yaml
│   ├── worker-service.yaml
│   └── ingress.yaml
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml
│
├── docker-compose.yml
├── .gitignore
├── README.md
└── plan.md
```

---

# 6. Phase 1 — Build Auth Service

## Objective

Create a small authentication microservice.

### Tasks

- Create Python application
- Create `/health` endpoint
- Create `/login` endpoint
- Add request validation
- Add unit tests
- Add requirements file

Example project:

```text
auth/
├── app/
│   └── main.py
├── tests/
│   └── test_auth.py
├── requirements.txt
└── Dockerfile
```

### Test Locally

Run:

```bash
pip install -r requirements.txt
```

Then:

```bash
python app/main.py
```

Test:

```text
http://localhost:<port>/health
```

---

# 7. Phase 2 — Build API Service

## Objective

Create the main application API.

### Tasks

- Create Python API
- Create `/health`
- Create `/api/data`
- Add request handling
- Add unit tests
- Add requirements file

Structure:

```text
api/
├── app/
│   └── main.py
├── tests/
│   └── test_api.py
├── requirements.txt
└── Dockerfile
```

Test locally.

---

# 8. Phase 3 — Build Worker Service

## Objective

Create a background-processing service.

### Tasks

- Create worker application
- Add background processing simulation
- Add logging
- Add health/status functionality
- Add unit tests
- Add requirements file

Structure:

```text
worker/
├── app/
│   └── main.py
├── tests/
│   └── test_worker.py
├── requirements.txt
└── Dockerfile
```

The worker should continuously demonstrate background processing without consuming excessive CPU.

---

# 9. Phase 4 — Add Unit Tests

Each service must have its own tests.

```text
auth/tests/
api/tests/
worker/tests/
```

Minimum testing goals:

- Health endpoint test
- Main functionality test
- Invalid input test where applicable

Run:

```bash
pytest
```

Expected result:

```text
All tests passed
```

---

# 10. Phase 5 — Add Code Linting

Introduce a Python linting tool.

Recommended:

```text
ruff
```

Install:

```bash
pip install ruff
```

Run:

```bash
ruff check .
```

The project should pass linting before Docker images are built.

---

# 11. Phase 6 — Create Dockerfiles

Each service needs an independent Dockerfile.

Example:

```text
auth/Dockerfile
api/Dockerfile
worker/Dockerfile
```

Each Dockerfile should:

1. Use a Python base image
2. Set the working directory
3. Copy dependency files
4. Install dependencies
5. Copy application code
6. Expose the required port where applicable
7. Start the application

---

# 12. Phase 7 — Build Docker Images

Build:

```bash
docker build -t auth-service ./auth
docker build -t api-service ./api
docker build -t worker-service ./worker
```

Check:

```bash
docker images
```

Expected:

```text
auth-service
api-service
worker-service
```

---

# 13. Phase 8 — Test Containers Individually

Run each service:

```bash
docker run -p <port>:<port> auth-service
```

Repeat for API and worker.

Check health endpoints.

Verify:

- Container starts
- Application starts
- Port is accessible
- Logs are generated
- Service responds correctly

---

# 14. Phase 9 — Create Docker Compose

Create:

```text
docker-compose.yml
```

Docker Compose should start all three services together.

Architecture:

```text
Docker Compose
│
├── auth
│
├── api
│
└── worker
```

Run:

```bash
docker compose up --build
```

Check:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs
```

Stop:

```bash
docker compose down
```

### Goal

The complete application should start with:

```bash
docker compose up
```

This demonstrates the reduction of multi-step local setup to a single command.

---

# 15. Phase 10 — Create Git Repository

Initialize:

```bash
git init
```

Create `.gitignore`.

Include:

```text
__pycache__/
*.pyc
.venv/
venv/
.env
*.log
.vscode/
.idea/
```

Do not commit:

- Passwords
- API keys
- Tokens
- `.env`
- Private credentials

Commit:

```bash
git add .
git commit -m "Initial microservice application"
```

---

# 16. Phase 11 — Create GitHub Repository

Create:

```text
microservice-cicd-kubernetes
```

Connect:

```bash
git remote add origin https://github.com/AswinArun321/microservice-cicd-kubernetes.git
```

Set main:

```bash
git branch -M main
```

Push:

```bash
git push -u origin main
```

---

# 17. Phase 12 — Create GitHub Actions CI Pipeline

Create:

```text
.github/
└── workflows/
    └── ci-cd.yml
```

The workflow should trigger on:

```yaml
on:
  push:
    branches:
      - main

  pull_request:
    branches:
      - main
```

---

# 18. CI Pipeline Stages

The pipeline should contain the following stages:

```text
Git Push
   |
   v
Checkout
   |
   v
Install Dependencies
   |
   v
Lint
   |
   v
Unit Tests
   |
   v
Docker Build
```

### Stage 1 — Checkout

Use:

```text
actions/checkout
```

---

### Stage 2 — Setup Python

Use the appropriate Python setup action.

---

### Stage 3 — Install Dependencies

Install requirements for each service.

---

### Stage 4 — Lint

Run:

```bash
ruff check .
```

---

### Stage 5 — Unit Tests

Run:

```bash
pytest
```

The pipeline should stop if tests fail.

---

# 19. Phase 13 — Docker Build in GitHub Actions

After tests pass, build all three images:

```text
auth-service
api-service
worker-service
```

Pipeline:

```text
Lint
  |
  v
Tests
  |
  v
Docker Build
```

Docker should only be built after the code passes validation.

---

# 20. Phase 14 — Container Registry

Choose one:

### Option A

GitHub Container Registry:

```text
ghcr.io
```

### Option B

Docker Hub.

For a GitHub-based portfolio project, GitHub Container Registry can keep the workflow closely integrated with the repository.

Images:

```text
auth-service
api-service
worker-service
```

---

# 21. Phase 15 — Configure Registry Authentication

Never hard-code credentials.

Use GitHub:

```text
Repository
   ↓
Settings
   ↓
Secrets and variables
   ↓
Actions
```

Store required credentials as GitHub Actions secrets where necessary.

---

# 22. Phase 16 — Push Docker Images

The CI/CD pipeline should:

```text
Git Push
    |
    v
Lint
    |
    v
Tests
    |
    v
Build Images
    |
    v
Push Images
```

Verify the images exist in the selected registry.

---

# 23. Phase 17 — Install Kubernetes Locally

Install Minikube.

Start:

```bash
minikube start
```

Check:

```bash
kubectl cluster-info
```

Check nodes:

```bash
kubectl get nodes
```

Expected:

```text
minikube   Ready
```

---

# 24. Phase 18 — Create Kubernetes Deployments

Create:

```text
k8s/
├── auth-deployment.yaml
├── api-deployment.yaml
└── worker-deployment.yaml
```

Each Deployment should define:

- Container image
- Number of replicas
- Container port where applicable
- Resource configuration
- Environment configuration where required

Architecture:

```text
Kubernetes Cluster
│
├── Auth Deployment
│
├── API Deployment
│
└── Worker Deployment
```

---

# 25. Phase 19 — Create Kubernetes Services

Create:

```text
auth-service.yaml
api-service.yaml
worker-service.yaml
```

Services provide stable networking for the workloads.

Architecture:

```text
Auth Deployment
      |
      v
 Auth Service


API Deployment
      |
      v
 API Service


Worker Deployment
      |
      v
Worker Service
```

---

# 26. Phase 20 — Create Kubernetes Ingress

Create:

```text
k8s/ingress.yaml
```

Ingress should provide external routing.

Example concept:

```text
                Ingress
                   |
       +-----------+-----------+
       |           |           |
       v           v           v
     /auth        /api      /worker
       |           |           |
       v           v           v
     Auth          API        Worker
    Service      Service     Service
```

Enable Minikube ingress:

```bash
minikube addons enable ingress
```

---

# 27. Phase 21 — Deploy to Kubernetes

Apply:

```bash
kubectl apply -f k8s/
```

Check:

```bash
kubectl get pods
```

Then:

```bash
kubectl get deployments
```

Then:

```bash
kubectl get services
```

Then:

```bash
kubectl get ingress
```

All required workloads should reach a healthy state.

---

# 28. Phase 22 — Debug Kubernetes Deployment

If a pod fails:

```bash
kubectl get pods
```

Then:

```bash
kubectl describe pod <pod-name>
```

View logs:

```bash
kubectl logs <pod-name>
```

Check deployment:

```bash
kubectl describe deployment <deployment-name>
```

Check services:

```bash
kubectl describe service <service-name>
```

---

# 29. Phase 23 — Test Kubernetes Application

Test:

```text
Auth Service
API Service
Worker Service
```

Verify:

- Pods are running
- Services are available
- Ingress routes correctly
- API returns expected response
- Worker is processing tasks
- No CrashLoopBackOff
- No image-pull errors

---

# 30. Phase 24 — Demonstrate Rolling Updates

Change the application version.

Build a new Docker image.

Push it to the registry.

Update the Kubernetes Deployment.

Example:

```bash
kubectl set image deployment/api-deployment \
api=<new-image>
```

Monitor:

```bash
kubectl rollout status deployment/api-deployment
```

Check:

```bash
kubectl get pods
```

The old pods should gradually be replaced by the new version.

---

# 31. Phase 25 — Rollback Testing

If a deployment fails:

```bash
kubectl rollout history deployment/api-deployment
```

Rollback:

```bash
kubectl rollout undo deployment/api-deployment
```

Verify:

```bash
kubectl rollout status deployment/api-deployment
```

This demonstrates Kubernetes deployment recovery.

---

# 32. Phase 26 — Optional AWS EKS Deployment

This is optional.

The project can first be completed entirely using:

```text
Docker
+
GitHub Actions
+
Minikube
+
Kubernetes
```

No paid cloud infrastructure is required for the core project.

If EKS is added later:

```text
GitHub Actions
       |
       v
Container Registry
       |
       v
AWS EKS
       |
       +---- Auth
       |
       +---- API
       |
       +---- Worker
```

Be careful with AWS costs and free-tier eligibility.

---

# 33. Phase 27 — Improve CI/CD Pipeline

Final pipeline:

```text
                    Git Push
                       |
                       v
                GitHub Actions
                       |
             +---------+---------+
             |                   |
             v                   v
           Lint                Tests
             |                   |
             +---------+---------+
                       |
                       v
                 Docker Build
                       |
                       v
                Image Registry
                       |
                       v
                  Kubernetes
                       |
                       v
                 Rolling Update
```

---

# 34. Phase 28 — Add Health Checks

Each service should expose a health endpoint where applicable.

Example:

```text
GET /health
```

Expected:

```json
{
  "status": "healthy"
}
```

Use these endpoints for:

- Local testing
- Docker testing
- Kubernetes health checks
- Troubleshooting

---

# 35. Phase 29 — Add Kubernetes Probes

Configure:

```text
livenessProbe
readinessProbe
```

Concept:

```text
Container
   |
   +---- Liveness Probe
   |
   +---- Readiness Probe
```

Liveness determines whether the container should be restarted.

Readiness determines whether the container should receive traffic.

---

# 36. Phase 30 — Add Resource Limits

Configure reasonable Kubernetes resource requests and limits.

Example:

```text
CPU Request
Memory Request

CPU Limit
Memory Limit
```

This prevents a single service from consuming uncontrolled resources.

---

# 37. Phase 31 — Security Improvements

Implement:

- No credentials in source code
- `.env` excluded from Git
- GitHub Actions secrets
- Kubernetes Secrets where appropriate
- Minimal container permissions
- Non-root Docker user where possible
- Dependency updates
- Image scanning

---

# 38. Phase 32 — Documentation

README must explain:

1. Project overview
2. Architecture
3. Technologies
4. Project structure
5. Docker setup
6. Docker Compose
7. CI/CD pipeline
8. Kubernetes deployment
9. Minikube setup
10. Useful Kubernetes commands
11. Troubleshooting
12. Future enhancements

Add screenshots of:

- GitHub Actions successful workflow
- Docker containers
- Kubernetes pods
- Kubernetes services
- Ingress
- Application running

---

# 39. Phase 33 — Final Testing

Perform the following complete test.

## Local Test

```bash
docker compose up --build
```

Verify all services.

---

## CI Test

Make a small code change:

```bash
git add .
git commit -m "Test CI pipeline"
git push
```

Check:

```text
GitHub
→ Actions
→ CI/CD Pipeline
```

Verify:

```text
✓ Checkout
✓ Dependencies
✓ Lint
✓ Tests
✓ Docker Build
✓ Image Push
```

---

## Kubernetes Test

Start:

```bash
minikube start
```

Deploy:

```bash
kubectl apply -f k8s/
```

Verify:

```bash
kubectl get pods
kubectl get services
kubectl get ingress
```

---

# 40. Phase 34 — Failure Testing

Intentionally test failures.

### Test 1 — Unit Test Failure

Introduce a failing test.

Expected:

```text
CI FAILED
```

Fix it and push again.

Expected:

```text
CI PASSED
```

---

### Test 2 — Lint Failure

Introduce a linting issue.

Expected:

```text
Lint FAILED
```

Fix and rerun.

---

### Test 3 — Kubernetes Failure

Deploy an invalid image.

Expected:

```text
ImagePullBackOff
```

Use:

```bash
kubectl describe pod <pod>
```

Fix the image and redeploy.

---

# 41. Phase 35 — Final Repository

Final repository should look approximately like:

```text
microservice-cicd-kubernetes/
│
├── auth/
│   ├── app/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
│
├── api/
│   ├── app/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
│
├── worker/
│   ├── app/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
│
├── k8s/
│   ├── auth-deployment.yaml
│   ├── auth-service.yaml
│   ├── api-deployment.yaml
│   ├── api-service.yaml
│   ├── worker-deployment.yaml
│   ├── worker-service.yaml
│   └── ingress.yaml
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml
│
├── docker-compose.yml
├── .gitignore
├── README.md
└── plan.md
```

---

# 42. Git Workflow

Use:

```bash
git status
git add .
git commit -m "Update microservice"
git push
```

For feature development:

```text
main
 |
 +---- feature/auth
 |
 +---- feature/api
 |
 +---- feature/worker
```

Merge completed features into `main`.

---

# 43. Final Project Checklist

## Application

- [ ] Auth service created
- [ ] API service created
- [ ] Worker service created
- [ ] Health endpoints implemented
- [ ] Unit tests implemented
- [ ] Linting configured

## Docker

- [ ] Auth Dockerfile
- [ ] API Dockerfile
- [ ] Worker Dockerfile
- [ ] Images build successfully
- [ ] Containers run successfully
- [ ] Docker Compose configured
- [ ] All services run using one command

## GitHub

- [ ] Repository created
- [ ] `.gitignore` added
- [ ] README added
- [ ] Project pushed
- [ ] GitHub Actions configured

## CI/CD

- [ ] Checkout
- [ ] Dependency installation
- [ ] Lint
- [ ] Unit tests
- [ ] Docker build
- [ ] Image push
- [ ] Pipeline passes successfully

## Kubernetes

- [ ] Minikube installed
- [ ] kubectl configured
- [ ] Auth Deployment
- [ ] API Deployment
- [ ] Worker Deployment
- [ ] Auth Service
- [ ] API Service
- [ ] Worker Service
- [ ] Ingress
- [ ] Pods running
- [ ] Services working
- [ ] Ingress working
- [ ] Rolling update tested
- [ ] Rollback tested

## Security

- [ ] No passwords in Git
- [ ] No API keys in Git
- [ ] `.env` ignored
- [ ] Secrets stored securely
- [ ] Docker images reviewed
- [ ] Dependencies reviewed

## Documentation

- [ ] README completed
- [ ] Architecture diagram
- [ ] Setup instructions
- [ ] Docker instructions
- [ ] CI/CD explanation
- [ ] Kubernetes instructions
- [ ] Troubleshooting section
- [ ] Screenshots
- [ ] Future enhancements

---

# 44. Final Expected Result

At the end of the project, the workflow should be:

```text
Developer
    |
    | git push
    v
GitHub
    |
    v
GitHub Actions
    |
    +---- Lint
    |
    +---- Unit Tests
    |
    +---- Docker Build
    |
    +---- Push Images
    |
    v
Container Registry
    |
    v
Kubernetes
    |
    +---- Auth
    |
    +---- API
    |
    +---- Worker
    |
    v
Ingress
    |
    v
Application
```

## Portfolio Achievement

The completed project should demonstrate practical understanding of:

- Microservices
- Docker
- Docker Compose
- CI/CD
- GitHub Actions
- Container registries
- Kubernetes
- Minikube
- Deployments
- Services
- Ingress
- Rolling updates
- Rollbacks
- Automated testing
- Infrastructure deployment concepts

The core project can be completed locally without paying for AWS. AWS EKS can remain an optional extension.