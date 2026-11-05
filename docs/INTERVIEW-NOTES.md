# Technical Interview & Architecture Defense Notes

This document provides concise, articulate explanations for the core engineering and security decisions made in this project. Use these answers during technical interviews and architectural reviews.

---

### Q1: Why did you use GitHub Actions OIDC federation instead of AWS IAM User access keys?
**Answer:**
"Static IAM access keys are one of the most common vectors for cloud credential leakage. They are long-lived, require periodic rotation, and if leaked in code, logs, or compromised secrets, provide persistent access to the AWS account.

By leveraging **OpenID Connect (OIDC)** with AWS IAM and GitHub Actions:
1. **Zero Static Credentials:** No AWS credentials are stored in GitHub Secrets or on workstations.
2. **Short-Lived Tokens:** AWS STS generates temporary credentials valid only for the duration of the workflow execution (typically 15 to 60 minutes).
3. **Cryptographic Trust:** IAM trust policies validate GitHub's signed OIDC JWT token against specific repository, branch, and environment claims, ensuring that only authorized workflows on specific branches can assume specific roles."

---

### Q2: Why did you create two separate IAM roles instead of a single CI/CD role?
**Answer:**
"This enforces the **Principle of Least Privilege (PoLP)** and **Separation of Concerns**:
1. The **`gha-ecr-push`** role is assumed during the CI build stage on the `master` branch. It only has permissions to authenticate to Amazon ECR and push container images to the three specific repositories. It has zero access to EKS or other cloud resources.
2. The **`gha-eks-deploy`** role is assumed only during the CD stage inside the protected GitHub Environment `dev`. In IAM, it only has `eks:DescribeCluster` permission; its Kubernetes access is tightly scoped via **EKS Access Entries** to the `microservices` namespace.

If the build pipeline or a third-party action were compromised during the test/build step, the attacker would only hold short-lived rights to push an image, not access or compromise the Kubernetes cluster."

---

### Q3: Why do you enforce immutable container image tags?
**Answer:**
"Using mutable tags like `:latest` in production introduces non-deterministic deployments and severe security risks:
- You cannot guarantee what version of code is running in a pod because `:latest` can change without manifest updates.
- Rollbacks are unpredictable: rolling back to `:latest` might pull a different image than what previously ran.
- Image tampering or cache pollution can introduce unvetted code.

We configure Amazon ECR with `image_tag_mutability = "IMMUTABLE"` and tag every container with its exact **Git commit SHA** (`${{ github.sha }}`). This provides an unbreakable audit trail from running Kubernetes pods back to the exact Git commit, and guarantees deterministic, reproducible rollouts and rollbacks."

---

### Q4: Why is `terraform apply` executed locally by the developer rather than automated in CI?
**Answer:**
"In enterprise and production architectures, automated `apply` without gatekeeping introduces a massive blast radius. Granting a CI runner permissions to provision or destroy VPCs, subnets, IAM roles, and EKS clusters means any pull request or pipeline flaw could inadvertently destroy production infrastructure or incur runaway cloud bills.

Instead, we follow a best-practice hybrid model:
- **CI Automation:** CI runs `terraform fmt -check`, `terraform init -backend=false`, and `terraform validate` to enforce syntax, module consistency, and style.
- **Controlled Application:** Infrastructure changes are generated as reviewed execution plans (`terraform plan -out=tfplan`) and applied by the authorized cloud operator with strict billing budget alerts in place."

---

### Q5: What does an AWS NAT Gateway cost, and how did you handle it in demo mode?
**Answer:**
"An AWS NAT Gateway costs **~$0.045 per hour** (~$32.40 per month baseline in `ap-south-1`) simply for existing, plus $0.045 per GB of data processed. For a two-AZ setup with high availability, two NAT Gateways cost ~$65/month even if zero traffic flows.

For this project's **cost-controlled demo mode**:
- We deployed worker nodes into public subnets across 2 AZs with strictly locked security groups and no open ingress, completely bypassing the NAT Gateway cost ($0.00).
- We parameterized the architecture with `enable_nat = false`. Enabling private subnets and a managed NAT Gateway for production compliance is a single-variable toggle (`enable_nat = true`), which we fully implement and document in `terraform/modules/network/main.tf`."

---

### Q6: How does automated rollback work when a deployment fails?
**Answer:**
"Our CD workflow (`deploy-dev.yml`) employs a multi-tiered verification and recovery strategy:
1. **Zero-Downtime Rolling Update:** Deployments configure `maxSurge: 1` and `maxUnavailable: 0`. Kubernetes spins up new pods and waits for readiness and startup probes to pass before terminating old pods.
2. **Rollout Await:** GitHub Actions runs `kubectl rollout status deployment/<name> --timeout=180s`. If containers crash or probes fail to return HTTP 200 within the timeout window, the command fails.
3. **Automated Rollback Hook:** The pipeline catches the failure step (`if: failure()`) and immediately executes `kubectl rollout undo deployment/<name> -n microservices`, restoring the cluster to the previous stable revision."

---

### Q7: What would you change to scale this architecture to enterprise production?
**Answer:**
"While this architecture is production-grade in security and automation, for a large-scale enterprise environment I would:
1. **GitOps with Argo CD:** Transition from push-based GitHub Actions deployments to pull-based GitOps with Argo CD running inside the cluster.
2. **AWS Secrets Manager & External Secrets Operator:** Replace static Kubernetes Secrets with AWS Secrets Manager synchronized dynamically via the Kubernetes External Secrets Operator (ESO).
3. **Private Subnets & Dual NAT Gateways:** Enable `enable_nat = true` across multiple AZs.
4. **Custom Domain & TLS via Route 53 + AWS ACM:** Attach an AWS Certificate Manager (ACM) TLS certificate to the Application Load Balancer for HTTPS termination on port 443.
5. **Observability Stack:** Deploy Prometheus Operator, Grafana, and AWS OpenTelemetry Collector for distributed tracing and SLO alerting."
