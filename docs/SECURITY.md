# Security Architecture & Best Practices

This document outlines the defense-in-depth security measures implemented across code, containers, CI/CD pipelines, Kubernetes workloads, and AWS cloud infrastructure.

---

## 1. Security Overview Matrix

| Domain | Control | Implementation |
|---|---|---|
| **Identity & Access** | Keyless CI/CD | GitHub Actions OIDC federation (`sts.amazonaws.com`); zero static AWS IAM access keys stored. |
| **Identity & Access** | Scoped IAM Roles | Two distinct roles: `gha-ecr-push` (scoped to `refs/heads/master`) and `gha-eks-deploy` (scoped to `environment:dev`). |
| **Kubernetes RBAC** | EKS Access Entries | Deployer role mapped strictly to `microservices` namespace using `AmazonEKSAdminPolicy`. |
| **Workload Security** | Non-Root User | Enforces `runAsNonRoot: true`, `runAsUser: 10001`, and `runAsGroup: 10001`. |
| **Workload Security** | Immutability | `readOnlyRootFilesystem: true` with temporary write buffer mounted on `emptyDir` at `/tmp`. |
| **Workload Security** | Capabilities | Linux capabilities dropped (`capabilities: drop: ["ALL"]`). Privilege escalation disabled (`allowPrivilegeEscalation: false`). |
| **Workload Security** | Seccomp Profile | Pods use `RuntimeDefault` seccomp profile to restrict malicious syscalls. |
| **Network Security** | Default Deny | NetworkPolicy defaults to denying all unapproved ingress and egress within the namespace. |
| **Supply Chain** | Vulnerability Scans | Trivy scans filesystem, dependencies, and built container images in CI; `pip-audit` scans Python packages. |
| **Secret Hygiene** | Gitleaks & K8s Secrets | Gitleaks runs on every PR/push; JWT secret decoupled to Kubernetes `Secret` (`app-secrets`). |
| **Registry Hygiene** | Immutable Tags | ECR repositories enforce `image_tag_mutability = "IMMUTABLE"` to prevent image spoofing. |

---

## 2. GitHub Actions OIDC Federation

Instead of generating permanent IAM users with secret access keys that risk compromise:
1. GitHub Actions requests an OpenID Connect (OIDC) JSON Web Token (JWT) from GitHub's OIDC Provider (`token.actions.githubusercontent.com`).
2. The runner presents this token to AWS Security Token Service (STS) using `sts:AssumeRoleWithWebIdentity`.
3. AWS STS validates the cryptographic signature against GitHub's public OIDC keys, confirms the audience (`sts.amazonaws.com`), and validates the subject (`sub`) claim.
4. AWS STS returns temporary, short-lived (15-60 min) security credentials.

### Exact Subject (`sub`) Claim Scoping
To prevent token spoofing from forks or unauthorized branches, trust policies enforce exact StringEquals/StringLike conditions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:AswinArun321/microservice-cicd-kubernetes:environment:dev",
            "repo:AswinArun321/microservice-cicd-kubernetes:ref:refs/heads/master"
          ]
        }
      }
    }
  ]
}
```

---

## 3. Pod Hardening Specification

Every Deployment in `k8s/base/` enforces strict Pod Security Standards (Restricted Profile):

```yaml
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: api-service
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
  volumes:
    - name: tmp-volume
      emptyDir: {}
```

- **`readOnlyRootFilesystem: true`**: Prevents an attacker from modifying executable binaries, installing malicious packages, or altering application code at runtime.
- **`emptyDir` on `/tmp`**: Allows Python temporary file operations (e.g., buffering uploads or file serialization) without permitting persistent or unbounded disk writes.
- **`automountServiceAccountToken: false`**: Eliminates unnecessary Kubernetes API token exposure within the container, preventing lateral movement to the Kubernetes control plane.

---

## 4. Network Isolation & Policies

The default NetworkPolicy in `k8s/base/networkpolicy.yaml` applies a **default-deny** ingress and egress rule to all pods in `microservices`:
- Egress is explicitly granted only to CoreDNS in `kube-system` on port 53 (UDP/TCP).
- Ingress is restricted to HTTP ports `5001`, `5002`, and `5003` from authorized ingress controller namespaces or intra-namespace pods.

