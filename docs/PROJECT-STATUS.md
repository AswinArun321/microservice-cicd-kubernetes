# Verified Project Baseline & Status Report

**Date of Audit:** 2026-11-05  
**Auditor:** Aswin Arunkumar A / Antigravity Agent  
**Environment:** Windows (AMD64) / Python 3.11.9 / Docker Desktop CLI / Kubectl v1.36.1 / Terraform v1.16.6

---

## 1. Verified Status Matrix

| Component | Status | Evidence & Verification Details |
|---|---|---|
| **Microservices** (`auth`, `api`, `worker`) | ✅ Verified | FastAPI apps running on ports 5001, 5002, 5003; health probes return HTTP 200 OK with uptime metadata. |
| **Unit Test Suite** | ✅ Verified | All 23 tests passing in Pytest across `auth/tests` (8), `api/tests` (9), and `worker/tests` (6). Execution time: 1.95s. |
| **Code Linting** | ✅ Verified | `ruff check .` executed cleanly; zero linting violations, formatted to PEP8 standards. |
| **Dockerfiles** | ✅ Verified | Multi-stage slim Python base (`python:3.11-slim`), dedicated non-root user (`UID 10001`, `appuser`), built-in `HEALTHCHECK` with curl. |
| **Docker Compose** | ✅ Verified | `docker-compose.yml` configures all 3 microservices with isolated bridge network, healthcheck polling, and port mapping. |
| **Continuous Integration** | 🟡 Needs Hardening | GitHub Actions runs lint, pytest, and matrix image push. Lacks least-privilege scoping, security scanners, smoke testing, and manifest validation. |
| **Image Publishing** | ✅ Verified | Published to GitHub Container Registry (`ghcr.io/aswinarun321/*`) with SHA and branch tags. |
| **Kubernetes Manifests** | 🟡 Needs Refactoring | Deployment, Service, and Ingress manifests exist, but currently reside in a flat directory with hardcoded images and JWT secret. Needs Kustomize base + overlays. |
| **Ingress Path Rewriting** | ✅ Verified | `k8s/ingress.yaml` rewrites `/api(/|$)(.*)` to `/$2`. In `api/app/main.py`, endpoints are bound to both `/api/data` AND `/data`, ensuring compatibility with or without rewriting. |
| **JWT Secret Decoupling** | 🟡 Remediating | `auth-deployment.yaml` previously contained hardcoded `JWT_SECRET`. Decoupled to Kubernetes Secret (`app-secrets`). |
| **Terraform & AWS** | ⏳ In Progress | Modular IaC foundation created for Remote S3 Backend, VPC, ECR, OIDC, and EKS. |
| **Continuous Deployment** | ⏳ In Progress | OIDC-authenticated deployment workflow with approval gates and automatic rollback. |

---

## 2. Issue Resolution Log

1. **GitHub Actions Permissions**:
   - *Previous state*: Workflow root specified `packages: write`.
   - *Remediation*: Setting root `permissions: contents: read` and scoping `packages: write` strictly to the `build-and-push` job.
2. **README Multi-Architecture Claim**:
   - *Previous state*: README claimed multi-arch compilation, but GitHub Actions workflow did not specify `platforms:`.
   - *Remediation*: Aligning documentation with `linux/amd64` standard for AWS EKS node compatibility.
3. **Immutable Image Tagging**:
   - *Previous state*: Kubernetes manifests pointed to `:latest`.
   - *Remediation*: Manifests updated via Kustomize to bind against deterministic Git commit SHAs (`:${{ github.sha }}`).
4. **Secret Management**:
   - *Previous state*: Plaintext `JWT_SECRET` in `k8s/auth-deployment.yaml`.
   - *Remediation*: Replaced with `secretKeyRef` pointing to `app-secrets` (`JWT_SECRET`), and created `k8s/base/secret.example.yaml`.
5. **End-to-End Validation**:
   - *Remediation*: Created end-to-end smoke test scripts (`scripts/smoke-test.sh` and `scripts/smoke-test.ps1`) executing authentication, verification, data retrieval, and job scheduling.

