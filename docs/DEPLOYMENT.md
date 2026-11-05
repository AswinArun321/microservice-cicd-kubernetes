# Deployment Runbook & Release Engineering

This document outlines deployment workflows, rollouts, rollbacks, and environment management for both Minikube and Amazon EKS.

---

## 1. Local Deployment (Minikube)

Minikube is the baseline zero-cost target for daily development and manifest validation.

### Deployment Procedure
```bash
# Apply full Kustomize bundle
kubectl apply -k k8s/overlays/minikube

# Monitor rollout status
kubectl rollout status deployment/auth-deployment -n microservices
kubectl rollout status deployment/api-deployment -n microservices
kubectl rollout status deployment/worker-deployment -n microservices
```

### Rollback Procedure
```bash
# View rollout revision history
kubectl rollout history deployment/api-deployment -n microservices

# Revert to previous revision
kubectl rollout undo deployment/api-deployment -n microservices
```

---

## 2. AWS EKS Cloud Deployment (Phases 7–9)

AWS deployments are executed through GitHub Actions using OpenID Connect (OIDC) identity federation.

### Step 1: Infrastructure Provisioning (Local Developer)
Per Architectural Decision **D4**, infrastructure modifications are planned and applied by the authorized operator:
```bash
cd terraform/envs/dev

# 1. Review plan carefully
terraform plan -out=tfplan

# 2. Apply reviewed changes
terraform apply tfplan

# 3. Retrieve outputs
terraform output
```

### Step 2: Configure GitHub Repository Variables
Add the following variables in GitHub repository settings (**Settings > Secrets and variables > Actions > Variables**):
- `AWS_REGION`: `ap-south-1`
- `EKS_CLUSTER_NAME`: Output from `terraform output eks_cluster_name`
- `AWS_EKS_DEPLOY_ROLE_ARN`: Output from `terraform output gha_eks_deploy_role_arn`
- `ECR_REGISTRY`: Output from `terraform output ecr_repository_urls` (registry domain prefix)

Add the following secret (**Settings > Secrets and variables > Actions > Secrets**):
- `JWT_SECRET`: A secure 32+ character random secret token for JWT signing.

### Step 3: Automated Pipeline Execution
1. Push changes to `master` branch.
2. The CI pipeline executes:
   - Ruff linting
   - Pytest unit tests (23 tests)
   - Trivy, Gitleaks, and pip-audit security scans
   - Kubeconform manifest validation
   - Docker Compose smoke test
   - Docker Buildx build & push to ECR with commit SHA tag.
3. Upon completion, the `Deploy to EKS (Dev)` workflow is triggered.
4. If configured with GitHub Environment Protection, an approved reviewer must authorize deployment.
5. The CD runner assumes `gha-eks-deploy` via OIDC, updates the Kustomize image tags, applies manifests to `microservices` namespace, awaits rollout status, and runs post-deployment verification.
6. If any pod fails readiness or probe checks within 180 seconds, the runner executes `kubectl rollout undo` automatically.

---

## 3. Manual Deployment / Hotfix

To manually trigger a deployment of a specific commit SHA without a new code push:
```bash
# Authenticate to AWS
aws eks update-kubeconfig --region ap-south-1 --name microservice-eks-dev

# Set image tags via Kustomize
cd k8s/overlays/eks
kustomize edit set image ghcr.io/aswinarun321/auth-service=123456789012.dkr.ecr.ap-south-1.amazonaws.com/auth-service:<COMMIT_SHA>
kustomize edit set image ghcr.io/aswinarun321/api-service=123456789012.dkr.ecr.ap-south-1.amazonaws.com/api-service:<COMMIT_SHA>
kustomize edit set image ghcr.io/aswinarun321/worker-service=123456789012.dkr.ecr.ap-south-1.amazonaws.com/worker-service:<COMMIT_SHA>

# Apply manifests
kubectl apply -k .

# Verify rollout
kubectl rollout status deployment/api-deployment -n microservices --timeout=120s
```
