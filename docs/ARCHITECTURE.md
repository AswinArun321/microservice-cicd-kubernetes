# System Architecture & Technical Specification

This document details the architectural design of the `microservice-cicd-kubernetes` platform across both **Local Development** and **AWS Cloud Production** deployment modes.

---

## 1. High-Level Architecture Overview

```mermaid
flowchart TD
    subgraph Developer_Workstation ["Developer Workstation"]
        Dev["Developer"] -->|git commit & push| Repo["GitHub Repository (master)"]
        Dev -.->|docker compose up| LocalCompose["Local Docker Compose"]
        Dev -.->|kubectl apply -k| LocalMini["Minikube Cluster"]
    end

    subgraph GitHub_Actions ["GitHub Actions CI/CD"]
        Repo --> CI["CI Pipeline"]
        CI --> Linter["Ruff Linter"]
        CI --> Pytest["Pytest (23 Unit Tests)"]
        CI --> SecurityScans["Trivy + Gitleaks + pip-audit"]
        CI --> ManifestValidation["Kubeconform + Terraform Validate"]
        CI --> SmokeTest["Docker Compose Smoke Test"]
        
        SmokeTest --> MatrixBuild["Docker Buildx (auth, api, worker)"]
        MatrixBuild --> GHCR["GitHub Container Registry (GHCR)"]
        MatrixBuild --> ECR["Amazon ECR (ap-south-1)"]

        ECR --> CD_Gate{"GitHub Environment: dev<br>(Manual Approval)"}
        CD_Gate -->|Approved| CD["CD Deploy Job"]
    end

    subgraph AWS_Cloud ["AWS Cloud Infrastructure (ap-south-1)"]
        OIDC["AWS IAM OIDC Provider"]
        RolePush["IAM Role: gha-ecr-push"]
        RoleDeploy["IAM Role: gha-eks-deploy"]
        
        MatrixBuild -->|AssumeRoleWithWebIdentity| RolePush
        CD -->|AssumeRoleWithWebIdentity| RoleDeploy

        subgraph VPC ["Amazon VPC (10.20.0.0/16)"]
            subgraph PublicSubnet1 ["Public Subnet ap-south-1a"]
                Node1["EKS Worker Node 1 (t3.medium)"]
            end
            subgraph PublicSubnet2 ["Public Subnet ap-south-1b"]
                Node2["EKS Worker Node 2 (t3.medium)"]
            end
            
            EKS_Control["EKS Control Plane v1.31<br>(API Access Entries)"]
            ALB["AWS Application Load Balancer"]
        end

        RoleDeploy -->|EKS Access Entry| EKS_Control
        EKS_Control --> Node1 & Node2
        ALB --> Node1 & Node2
    end
```

---

## 2. Microservices Architecture

The system is decomposed into three specialized, loosely coupled services:

```mermaid
flowchart LR
    Client["Client / Ingress"] -->|/auth/*| Auth["Auth Microservice<br>(Port 5001)<br>FastAPI + PyJWT"]
    Client -->|/api/*| API["Core API Microservice<br>(Port 5002)<br>FastAPI + Pydantic v2"]
    Client -->|/worker/*| Worker["Worker Microservice<br>(Port 5003)<br>FastAPI + Asyncio Task Loop"]
```

### 1. Auth Service (`auth/`, Port 5001)
- **Role:** Handles user authentication, credential validation, cryptographic JWT token generation (HS256), and signature verification.
- **Key Endpoints:**
  - `GET /health`: Liveness probe with service metadata and UTC timestamp.
  - `GET /`: Discovery endpoint returning supported operations.
  - `POST /login`: Validates credentials against credential store and issues signed JWT bearer tokens.
  - `POST /verify`: Decodes and validates JWT tokens, returning claims and expiration status.
- **Security:** Decoupled `JWT_SECRET` injected via Kubernetes Secret `app-secrets`.

### 2. API Service (`api/`, Port 5002)
- **Role:** Core business domain service exposing data records, category filtering, item creation, and statistical aggregations.
- **Key Endpoints:**
  - `GET /health`: Readiness and liveness probe with uptime metrics.
  - `GET /api/data` & `GET /data`: Fetches datasets with optional category filter and pagination limit.
  - `GET /api/data/{id}` & `GET /data/{id}`: Retrieves single record or returns HTTP 404.
  - `POST /api/data` & `POST /data`: Creates and stores new records (HTTP 201 Created).
  - `GET /api/stats` & `GET /stats`: Statistical distribution across item categories.
- **Dual-Path Routing:** Binds both `/api/data` and `/data` to guarantee seamless compatibility with NGINX regex path rewrites or direct ALB path forwarding.

### 3. Worker Service (`worker/`, Port 5003)
- **Role:** Background task processor and queue simulation service.
- **Key Endpoints:**
  - `GET /health`: Probe returning cumulative processed jobs and uptime.
  - `GET /status`: Telemetry dashboard showing background task state, loop interval, and recent task history.
  - `POST /jobs`: Asynchronously enqueues on-demand maintenance tasks.
- **Async Runtime:** Employs FastAPI lifespan handlers managing a persistent `asyncio.Task` background processing loop.

---

## 3. Network Topology & Traffic Routing

### AWS Network Architecture
- **VPC CIDR:** `10.20.0.0/16`
- **Subnet Layout:**
  - `10.20.1.0/24`: Public Subnet in `ap-south-1a` (tagged `kubernetes.io/role/elb = 1`)
  - `10.20.2.0/24`: Public Subnet in `ap-south-1b` (tagged `kubernetes.io/role/elb = 1`)
- **Cost-Optimized Demo Mode:**
  - Worker nodes are placed in public subnets with security group isolation (no open ingress except via ALB or restricted management CIDRs).
  - **Zero NAT Gateway Cost:** Eliminates the ~$32.40/month baseline NAT charge while maintaining multi-AZ EKS resilience.
- **Production Mode (Toggleable via `enable_nat = true`):**
  - Worker nodes placed in private subnets (`10.20.10.0/24`, `10.20.20.0/24`).
  - Outbound internet access mediated through an Elastic IP and managed NAT Gateway.

### Kubernetes Ingress Path Mapping

```text
Incoming Traffic (HTTP Port 80)
           │
           ├─► /auth(/.*)   ──► auth-service:5001   (Auth & JWT)
           ├─► /api(/.*)    ──► api-service:5002    (Business Data)
           └─► /worker(/.*) ──► worker-service:5003 (Worker & Telemetry)
```

---

## 4. Kubernetes In-Cluster Architecture (`microservices` Namespace)

```mermaid
graph TD
    subgraph K8s_Namespace ["Kubernetes Namespace: microservices"]
        Ingress["Ingress Controller<br>(NGINX on Minikube / ALB on EKS)"]
        
        subgraph Auth_Workload ["Auth Service (Port 5001)"]
            AuthDep["auth-deployment<br>(Replicas: 2, RollingUpdate)"]
            AuthSvc["auth-service (ClusterIP)"]
            AuthHPA["auth-hpa (Min: 2, Max: 4, CPU: 70%)"]
            AuthPDB["auth-pdb (minAvailable: 1)"]
            AuthDep --> AuthSvc
            AuthHPA -.-> AuthDep
            AuthPDB -.-> AuthDep
        end

        subgraph API_Workload ["API Service (Port 5002)"]
            APIDep["api-deployment<br>(Replicas: 2, RollingUpdate)"]
            APISvc["api-service (ClusterIP)"]
            APIHPA["api-hpa (Min: 2, Max: 4, CPU: 70%)"]
            APIPDB["api-pdb (minAvailable: 1)"]
            APIDep --> APISvc
            APIHPA -.-> APIDep
            APIPDB -.-> APIDep
        end

        subgraph Worker_Workload ["Worker Service (Port 5003)"]
            WorkerDep["worker-deployment<br>(Replicas: 1)"]
            WorkerSvc["worker-service (ClusterIP)"]
            WorkerDep --> WorkerSvc
        end

        Secret["Secret: app-secrets<br>(JWT_SECRET)"]
        Secret -.->|secretKeyRef| AuthDep

        NetPol["NetworkPolicy: default-deny-all<br>+ allow-microservices-traffic"]
        NetPol -.-> AuthDep & APIDep & WorkerDep
    end

    Ingress --> AuthSvc
    Ingress --> APISvc
    Ingress --> WorkerSvc
```

---

## 5. Security & Isolation Boundaries

1. **Identity & Credentials:**
   - No long-lived AWS IAM user access keys in repository secrets.
   - Authentication mediated via GitHub Actions OpenID Connect (OIDC) identity federation (`token.actions.githubusercontent.com`).
2. **Access Scoping:**
   - ECR Push Role scoped strictly to branch `master`.
   - EKS Deploy Role scoped to GitHub Environment `dev`.
   - EKS API Access Entries grant deployer role permissions strictly inside namespace `microservices`.
3. **Pod Hardening:**
   - Non-root user execution (`UID 10001`, `runAsNonRoot: true`).
   - Root filesystem mounted read-only (`readOnlyRootFilesystem: true`).
   - Linux capabilities dropped (`capabilities: drop: ["ALL"]`).
   - Privilege escalation blocked (`allowPrivilegeEscalation: false`).
   - Temporary write buffer confined to an `emptyDir` mounted at `/tmp`.

