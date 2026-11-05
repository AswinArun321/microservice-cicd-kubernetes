# Operational Troubleshooting & Diagnostics Guide

This guide provides targeted diagnostics and resolutions for common issues encountered during development, CI/CD, Kubernetes orchestration, and AWS provisioning.

---

## 1. Kubernetes Workload Issues

### Issue: `CrashLoopBackOff` on Service Pods
- **Symptoms:** Pods repeatedly restart; status alternates between `Error` and `CrashLoopBackOff`.
- **Diagnosis:**
  ```bash
  # Check container logs
  kubectl logs -n microservices <pod-name> --previous

  # Inspect pod lifecycle events
  kubectl describe pod -n microservices <pod-name>
  ```
- **Common Causes & Fixes:**
  1. *Missing Secret:* If `JWT_SECRET` is missing in `app-secrets`, the pod will fail to start. Ensure `app-secrets` exists:
     ```bash
     kubectl get secret app-secrets -n microservices
     ```
  2. *Filesystem write error:* Pods run with `readOnlyRootFilesystem: true`. If application code attempts to write to `./` instead of `/tmp`, Python will throw an `OSError: [Errno 30] Read-only file system`. Ensure any file writes target `/tmp`.
  3. *Health probe timeout:* Liveness probe timed out before Uvicorn bound the port. Increase `initialDelaySeconds` from 5 to 15.

---

### Issue: `ImagePullBackOff` / `ErrImagePull`
- **Symptoms:** Pods remain in `ImagePullBackOff` without starting.
- **Diagnosis:**
  ```bash
  kubectl describe pod -n microservices <pod-name>
  ```
- **Common Causes & Fixes:**
  1. *Private GHCR Package:* GHCR packages default to private upon first push. Either make the repository public in GitHub Package Settings or add a Kubernetes `imagePullSecret`.
  2. *ECR Authentication on EKS:* Ensure worker nodes have the `AmazonEC2ContainerRegistryReadOnly` policy attached to their IAM role. In this project's Terraform configuration, this is automatically managed by `terraform/modules/eks/main.tf`.
  3. *Tag Mismatch:* Verify the image tag in `k8s/overlays/eks/kustomization.yaml` matches the exact Git commit SHA pushed to ECR.

---

### Issue: Ingress Returns HTTP 404 or 503
- **Symptoms:** `curl http://<ingress-ip>/auth/health` returns `404 Not Found` or `503 Service Temporarily Unavailable`.
- **Diagnosis:**
  ```bash
  kubectl describe ingress microservice-ingress -n microservices
  kubectl get endpoints -n microservices
  ```
- **Fixes:**
  1. *Endpoints empty:* Ensure service selectors match deployment labels (`app: auth-service`).
  2. *Minikube Ingress Addon disabled:* Run `minikube addons enable ingress`.
  3. *Path Rewriting:* In NGINX Ingress, verify `nginx.ingress.kubernetes.io/rewrite-target: /$2`. Notice that the API service code in `api/app/main.py` explicitly supports both `/data` and `/api/data`.

---

## 2. GitHub Actions CI/CD & OIDC Issues

### Issue: `sts:AssumeRoleWithWebIdentity` Access Denied
- **Symptoms:** GitHub Actions step fails with `Not authorized to perform sts:AssumeRoleWithWebIdentity`.
- **Diagnosis:**
  Check GitHub Actions run logs for the exact token claims.
- **Common Causes & Fixes:**
  1. *Branch / Environment mismatch:* The trust policy in `terraform/modules/github-oidc/main.tf` restricts `sub` to:
     - `repo:<owner>/<repo>:ref:refs/heads/master` (for ECR push)
     - `repo:<owner>/<repo>:environment:dev` (for EKS deploy)
     If deploying from a pull request or an unconfigured environment, AWS STS will intentionally reject the call.
  2. *Missing Repository Variables:* Verify `AWS_EKS_DEPLOY_ROLE_ARN`, `AWS_REGION`, and `EKS_CLUSTER_NAME` are defined in GitHub Repository Variables.

---

## 3. Terraform & AWS Issues

### Issue: Terraform S3 State Lock Error
- **Symptoms:** `Error acquiring the state lock: ConditionalCheckFailedException`.
- **Resolution:**
  Terraform v1.10+ uses native S3 locking with `.tflock` objects. If a prior run was forcefully interrupted:
  ```bash
  terraform force-unlock <LOCK_ID>
  ```

### Issue: Subnet Deletion Fails During `terraform destroy`
- **Symptoms:** Terraform hangs on destroying subnets or VPC: `DependencyViolation: The subnet has dependencies and cannot be deleted`.
- **Cause:** The AWS Load Balancer Controller created an ALB or Elastic Network Interfaces (ENIs) inside the subnet that are not tracked in Terraform state.
- **Resolution:**
  Delete the Kubernetes ingress first:
  ```bash
  kubectl delete ingress -A --all
  # Wait 60s for ALB removal, then re-run terraform destroy
  terraform destroy -auto-approve
  ```

