# Comprehensive Setup Guide

This guide covers local environment initialization, container testing, Kubernetes cluster setup, and AWS cloud prerequisites.

---

## 1. Local Prerequisites & Installation

Ensure the following tools are installed on your workstation:
- **Python**: 3.11+
- **Docker & Docker Compose**: Docker Desktop / Docker Engine
- **Kubernetes CLI**: `kubectl` (v1.28+)
- **Minikube** (for local cluster execution)
- **Terraform**: v1.10+ (for cloud infrastructure)
- **AWS CLI**: v2 (for AWS deployment)

Verify your CLI versions:
```bash
python --version
docker --version
kubectl version --client
terraform -version
aws --version
```

---

## 2. Local Python Environment & Unit Testing

1. **Clone the repository**:
   ```bash
   git clone https://github.com/AswinArun321/microservice-cicd-kubernetes.git
   cd microservice-cicd-kubernetes
   ```

2. **Create and activate a virtual environment**:
   ```bash
   # On Windows PowerShell:
   python -m venv venv
   .\venv\Scripts\Activate.ps1

   # On Linux/macOS:
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install dependencies**:
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```

4. **Execute Code Quality & Test Suite**:
   ```bash
   # Lint check
   ruff check .

   # Unit tests (23 tests across auth, api, worker)
   pytest -v
   ```

---

## 3. Local Containerization with Docker Compose

Launch the entire 3-service stack locally:
```bash
# Build and start services in detached mode
docker compose up -d --build

# Verify running container state
docker compose ps

# Run the automated end-to-end smoke test
./scripts/smoke-test.sh
# or on Windows PowerShell:
.\scripts\smoke-test.ps1

# Inspect logs
docker compose logs -f

# Teardown stack
docker compose down -v
```

---

## 4. Local Kubernetes with Minikube & Kustomize

1. **Start Minikube and enable Ingress**:
   ```bash
   minikube start --driver=docker
   minikube addons enable ingress
   minikube addons enable metrics-server
   ```

2. **Deploy the application using Kustomize**:
   ```bash
   kubectl apply -k k8s/overlays/minikube
   ```

3. **Verify running pods and services**:
   ```bash
   kubectl get pods -n microservices
   kubectl get svc -n microservices
   kubectl get ingress -n microservices
   kubectl get hpa -n microservices
   ```

4. **Access the Application via Ingress**:
   ```bash
   MINIKUBE_IP=$(minikube ip)
   curl http://$MINIKUBE_IP/auth/health
   curl http://$MINIKUBE_IP/api/health
   curl http://$MINIKUBE_IP/worker/health
   ```

---

## 5. AWS Cloud Setup & Budget Protection (Phase 3)

Before running any Terraform commands, configure AWS credentials and budget safeguards:

1. **AWS Identity & CLI Configuration**:
   ```bash
   aws configure
   # Set AWS Access Key ID, Secret Access Key, and Default Region: ap-south-1
   aws sts get-caller-identity
   ```

2. **Create a Cost Alert Budget**:
   Set a monthly budget threshold (e.g., $10 USD) with notifications at 50%, 80%, and 100% via the AWS Console (AWS Budgets) or AWS CLI.

3. **Terraform S3 State Bootstrap**:
   ```bash
   cd terraform/bootstrap
   terraform init
   terraform plan -out=bootstrap.tfplan
   terraform apply bootstrap.tfplan
   ```
   Note the output `state_bucket_name`. Update `terraform/envs/dev/backend.tf` with this bucket name.

4. **Initialize Dev Environment**:
   ```bash
   cd ../envs/dev
   terraform init
   terraform plan
   ```

