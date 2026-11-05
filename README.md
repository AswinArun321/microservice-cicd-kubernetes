# Cloud-Native Microservices CI/CD & Kubernetes Orchestration on AWS

[![CI/CD Pipeline](https://github.com/AswinArun321/microservice-cicd-kubernetes/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/AswinArun321/microservice-cicd-kubernetes/actions/workflows/ci-cd.yml)
[![Python 3.11](https://img.shields.io/badge/python-3.11-blue.svg)](https://www.python.org/downloads/)
[![Code Style: Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)
[![Tests: Pytest](https://img.shields.io/badge/tests-23%20passed-brightgreen.svg)](https://docs.pytest.org/)
[![Security: Trivy](https://img.shields.io/badge/security-trivy%20%7C%20gitleaks%20%7C%20pip--audit-blueviolet.svg)](https://github.com/aquasecurity/trivy)
[![Infrastructure: Terraform](https://img.shields.io/badge/IaC-Terraform%20v1.10%2B-623CE4.svg)](https://www.terraform.io/)
[![Cloud: AWS EKS](https://img.shields.io/badge/cloud-AWS%20EKS%20v1.31-FF9900.svg)](https://aws.amazon.com/eks/)
[![Packaging: Kustomize](https://img.shields.io/badge/k8s-kustomize-326CE5.svg)](https://kustomize.io/)

A production-grade, portfolio-ready **3-service microservice platform** engineered with **FastAPI**, **Docker**, **GitHub Actions OIDC**, **Kustomize**, **Terraform IaC**, and **Amazon EKS**.

The project implements a **local-first, cost-controlled cloud architecture**: all features are 100% testable locally via Docker Compose and Minikube at zero cost, while supporting automated, keyless continuous deployment to AWS EKS with automated canary validation and rollback.

---

## Technical Documentation Suite

For comprehensive deep dives into each architectural domain, refer to the documentation in [`docs/`](docs/):

- 🏛️ [**System Architecture & Topology**](docs/ARCHITECTURE.md) — Comprehensive technical specs, data flows, and network designs.
- 📋 [**Architectural Decisions Record (ADR)**](docs/DECISIONS.md) — Decisions D1 through D8 with trade-off analyses.
- 🚀 [**Setup & Installation Guide**](docs/SETUP.md) — Step-by-step developer onboarding and AWS setup.
- 📦 [**Deployment & Release Runbook**](docs/DEPLOYMENT.md) — Minikube and AWS deployment and rollback commands.
- 🛡️ [**Security & Hardening Architecture**](docs/SECURITY.md) — Pod Security Standards, OIDC trust policies, and least-privilege scoping.
- 💰 [**Cloud Cost Control & Teardown Protocol**](docs/COST-AND-CLEANUP.md) — Exact resource auditing, pricing breakdowns, and destroy procedures.
- 🔧 [**Diagnostics & Troubleshooting Guide**](docs/TROUBLESHOOTING.md) — Resolutions for common Kubernetes and cloud issues.
- 🎙️ [**Technical Interview Defense Notes**](docs/INTERVIEW-NOTES.md) — Engineering explanations and architectural defense Q&A.
- 📊 [**Verified Project Status Log**](docs/PROJECT-STATUS.md) — Audit trails and baseline test verifications.

---

## Table of Contents

- [Project Architecture](#project-architecture)
- [Microservices Specifications](#microservices-specifications)
  - [1. Auth Service (Port 5001)](#1-auth-service-port-5001)
  - [2. API Service (Port 5002)](#2-api-service-port-5002)
  - [3. Worker Service (Port 5003)](#3-worker-service-port-5003)
- [Local Development & Validation](#local-development--validation)
- [Kubernetes Packaging with Kustomize](#kubernetes-packaging-with-kustomize)
- [Terraform Infrastructure as Code (AWS)](#terraform-infrastructure-as-code-aws)
- [CI/CD Pipeline & Keyless OIDC Deployment](#cicd-pipeline--keyless-oidc-deployment)
- [Security Controls & Pod Hardening](#security-controls--pod-hardening)
- [Cost Optimization & Teardown Protocol](#cost-optimization--teardown-protocol)
- [Known Limitations & Future Enhancements](#known-limitations--future-enhancements)
- [Author & License](#author--license)

---

## Project Architecture

### Dual-Target Architecture (Local vs AWS Cloud)

```text
                                  Developer
                                      │
                   ┌──────────────────┴──────────────────┐
                   ▼                                     ▼
        [Local Development]                      [Cloud CI/CD]
      Docker Compose / Minikube               git push to master
                   │                                     │
         k8s/overlays/minikube                           ▼
         - NGINX Ingress                          GitHub Actions
         - ClusterIP Services                            │
         - GHCR Images                       ┌───────────┴───────────┐
                                             ▼                       ▼
                                       Ruff + Pytest          Security Scans
                                       (23 Unit Tests)     (Trivy, Gitleaks, Audit)
                                             │                       │
                                             └───────────┬───────────┘
                                                         │
                                                         ▼
                                                Compose Smoke Test
                                                         │
                                                         ▼
                                               Docker Buildx (linux/amd64)
                                                         │
                                                         ▼
                                       OIDC: sts:AssumeRoleWithWebIdentity
                                       (IAM Role: gha-ecr-push)
                                                         │
                                                         ▼
                                             Amazon ECR (Immutable SHA Tags)
                                                         │
                                            Protected Environment: dev
                                            (Manual Review & Approval)
                                                         │
                                                         ▼
                                       OIDC: sts:AssumeRoleWithWebIdentity
                                       (IAM Role: gha-eks-deploy)
                                                         │
                                                         ▼
                                         Amazon EKS (ap-south-1)
                                         - Namespace: microservices
                                         - Kustomize Overlays (k8s/overlays/eks)
                                         - HPA + PDB + NetworkPolicy
                                         - Application Load Balancer (ALB)
                                         - Automatic Rollback on Failure
```

---

## Microservices Specifications

The platform is decomposed into three specialized, containerized microservices:

| Microservice | Port | Framework | Responsibilities | Key Endpoints |
|---|---|---|---|---|
| **Auth Service** | `5001` | FastAPI, PyJWT | Credential verification, token issuance, cryptographic verification | `POST /login`, `POST /verify`, `GET /health` |
| **API Service** | `5002` | FastAPI, Pydantic v2 | Business domain datasets, filtering, statistical aggregations | `GET /data`, `POST /data`, `GET /stats`, `GET /health` |
| **Worker Service** | `5003` | FastAPI, Asyncio | Async background task scheduler, queue simulation, telemetry | `POST /jobs`, `GET /status`, `GET /health` |

### Ingress Path Routing
- `/auth(/.*)` &rarr; `auth-service:5001`
- `/api(/.*)` &rarr; `api-service:5002` (Code natively supports dual paths `/data` and `/api/data` to support prefix-stripping or direct routing)
- `/worker(/.*)` &rarr; `worker-service:5003`

---

## Local Development & Validation

### 1. Environment Setup & Tests
```bash
# Set up Python virtual environment
python -m venv venv
source venv/bin/activate  # Or .\venv\Scripts\Activate.ps1 on Windows

# Install dependencies
pip install -r requirements.txt

# Run linter and test suite
ruff check .
pytest -v
```

### 2. Docker Compose Stack
```bash
# Build and run containers
docker compose up -d --build

# Run automated end-to-end smoke test
chmod +x scripts/smoke-test.sh
./scripts/smoke-test.sh

# Teardown containers
docker compose down -v
```

### 3. Minikube Deployment
```bash
# Start cluster with ingress
minikube start --driver=docker
minikube addons enable ingress
minikube addons enable metrics-server

# Deploy with Kustomize
kubectl apply -k k8s/overlays/minikube

# Verify workloads
kubectl get pods,svc,ingress,hpa -n microservices
```

---

## Kubernetes Packaging with Kustomize

Workloads are structured using native Kustomize manifests:

```text
k8s/
├── base/                              # Common baseline specifications
│   ├── kustomization.yaml             # Kustomize manifest index
│   ├── namespace.yaml                 # Dedicated 'microservices' namespace
│   ├── secret.example.yaml            # Secret blueprint (JWT_SECRET)
│   ├── auth-deployment.yaml           # Replicas, probes, security context
│   ├── auth-service.yaml              # ClusterIP service
│   ├── api-deployment.yaml            # Replicas, probes, security context
│   ├── api-service.yaml               # ClusterIP service
│   ├── worker-deployment.yaml         # Background worker deployment
│   ├── worker-service.yaml            # ClusterIP service
│   ├── hpa.yaml                       # HorizontalPodAutoscalers (CPU 70%)
│   ├── pdb.yaml                       # PodDisruptionBudgets (minAvailable: 1)
│   ├── networkpolicy.yaml             # Default-deny & explicit allow policies
│   └── ingress.yaml                   # NGINX Ingress specification
└── overlays/
    ├── minikube/                      # Local Minikube overlay
    │   └── kustomization.yaml
    └── eks/                           # Production AWS EKS overlay
        ├── kustomization.yaml         # ECR image mappings
        └── ingress-alb-patch.yaml     # AWS Load Balancer Controller patch
```

---

## Terraform Infrastructure as Code (AWS)

Modular Terraform provisions all cloud infrastructure in **`ap-south-1` (Mumbai)**:

```text
terraform/
├── bootstrap/                         # Remote state foundation
│   ├── main.tf                        # S3 bucket, versioning, SSE, public block, TLS policy
│   ├── variables.tf
│   └── outputs.tf
├── modules/
│   ├── network/                       # VPC, 2 AZ public subnets, IGW, discovery tags
│   ├── ecr/                           # 3 ECR repos, immutable tags, lifecycle rules
│   ├── github-oidc/                   # GitHub Actions OIDC provider & scoped IAM roles
│   └── eks/                           # EKS v1.31, AL2023 node group, API access entries
└── envs/
    └── dev/
        ├── backend.tf                 # S3 backend with native locking (use_lockfile = true)
        ├── main.tf                    # Module composition
        ├── variables.tf
        └── outputs.tf
```

### Infrastructure Workflow
```bash
# 1. Bootstrap remote S3 state (run once locally)
cd terraform/bootstrap
terraform init && terraform apply

# 2. Deploy dev environment
cd ../envs/dev
# Update bucket name in backend.tf, then:
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 3. Configure kubectl for EKS
aws eks update-kubeconfig --region ap-south-1 --name microservice-eks-dev
```

---

## CI/CD Pipeline & Keyless OIDC Deployment

The project features a **two-stage automated pipeline**:

1. **Continuous Integration ([`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml))**:
   - Least-privilege permissions (`contents: read` at root; `packages: write` on build only).
   - Ruff linting and Pytest unit testing (23 tests).
   - Trivy filesystem & IaC scanning, Gitleaks secret detection, and pip-audit.
   - Kubernetes manifest (`kubeconform -strict`) and Terraform (`fmt`, `validate`) validation.
   - Multi-container Docker Compose end-to-end smoke test.
   - Docker Buildx compilation for `linux/amd64` and push with Git commit SHA tags.

2. **Continuous Deployment ([`.github/workflows/deploy-dev.yml`](.github/workflows/deploy-dev.yml))**:
   - Uses AWS OIDC Identity Federation (zero static secrets).
   - Gated behind protected GitHub Environment `dev` requiring manual approval.
   - Assumes `gha-eks-deploy` scoped strictly to namespace `microservices`.
   - Dynamically updates Kustomize image tags with the commit SHA.
   - Awaits rollout completion (`kubectl rollout status --timeout=180s`).
   - Executes post-deployment smoke test.
   - Automatically executes `kubectl rollout undo` on failure.

---

## Security Controls & Pod Hardening

Adheres to Kubernetes **Restricted Pod Security Standards**:
- **Non-Root Execution**: `runAsNonRoot: true`, `runAsUser: 10001`, `runAsGroup: 10001`.
- **Immutable Root Filesystem**: `readOnlyRootFilesystem: true` with `/tmp` mounted on an `emptyDir` buffer.
- **Capabilities Dropped**: `capabilities: drop: ["ALL"]`, `allowPrivilegeEscalation: false`.
- **Seccomp Profile**: `RuntimeDefault` enabled on all pods.
- **Network Isolation**: Default-deny NetworkPolicy isolating intra-cluster communication.
- **Keyless Authentication**: AWS STS OIDC with scoped `sub` condition claims.

---

## Cost Optimization & Teardown Protocol

> [!WARNING]
> To prevent unnecessary cloud charges, tear down demo clusters on the same day.

### Destruction Sequence
```bash
# 1. Delete Kubernetes ingress to clean up AWS ALB
kubectl delete -k k8s/overlays/eks

# 2. Destroy cloud infrastructure with Terraform
cd terraform/envs/dev
terraform apply -destroy -auto-approve

# 3. Audit account to guarantee zero remaining billable resources
aws eks list-clusters --region ap-south-1
aws elbv2 describe-load-balancers --region ap-south-1
aws ec2 describe-nat-gateways --region ap-south-1 --filter Name=state,Values=available
```
Refer to [`docs/COST-AND-CLEANUP.md`](docs/COST-AND-CLEANUP.md) for full audit checklists.

---

## Known Limitations & Future Enhancements

### Known Limitations
- **Public Nodes in Demo Mode**: Worker nodes reside in public subnets with restrictive security groups to avoid NAT Gateway charges (~$32.40/mo). Production setups toggle `enable_nat = true`.
- **Manual Infrastructure Apply**: `terraform apply` is executed locally by the operator to prevent automated cloud destruction risks.

### Future Enhancements
- [ ] GitOps continuous deployment using **Argo CD** in-cluster.
- [ ] Automated secret synchronization using **AWS Secrets Manager** and **External Secrets Operator (ESO)**.
- [ ] Custom domain registration and automated TLS certificate issuance via **Route 53** and **AWS ACM**.
- [ ] Distributed tracing and metrics with **Prometheus Operator** and **Grafana dashboards**.

---

## Author & License

**Aswin Arunkumar A**  
MSc Computer Science (Data Analytics)  
Rajagiri College of Social Sciences  
GitHub: [@AswinArun321](https://github.com/AswinArun321)

This project is licensed under the **MIT License**.
