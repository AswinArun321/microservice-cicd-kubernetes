# microservice-cicd-kubernetes — Project Completion Plan (v2)

**Repository:** https://github.com/AswinArun321/microservice-cicd-kubernetes
**Plan date:** 2026-11-05
**Goal:** Take the existing 3-service FastAPI app (CI + Kubernetes on Minikube already built) to a portfolio-grade **AWS + Terraform + EKS + secure CD** project, with every cloud step cost-controlled and reversible.

> **What changed from v1:** v1 was written without seeing the repo and assumed nothing existed. The repo has since been inspected: the app, Dockerfiles, Compose, Ruff/Pytest CI, GHCR publishing and Kubernetes manifests **already exist**. v2 drops the rebuild work, adds a hardening pass on what exists, and focuses effort on what is genuinely missing: Terraform, AWS, EKS, OIDC, CD, scanning and AWS docs.

---

## 1. Where the project actually stands

Evidence below comes from the README, `.github/workflows/ci-cd.yml` and `k8s/ingress.yaml`. Items marked **Verify** were claimed in the README but I could not see the underlying file (Dockerfiles, `docker-compose.yml`, `k8s/*-deployment.yaml`, the repo's current `plan.md`). Confirm them in Phase 0.

| Component | Status | Evidence / note |
|---|---|---|
| Microservices (`auth` 5001, `api` 5002, `worker` 5003) | ✅ Done | FastAPI, Pydantic v2, JWT; `/health` on each |
| Unit tests | ✅ Done | 23 tests (8 auth, 9 api, 6 worker) per README |
| Lint | ✅ Done | Ruff in CI and `pyproject.toml` |
| Dockerfiles | ✅ Done — **Verify** | Claimed multi-stage, non-root UID 10001, HEALTHCHECK |
| Docker Compose | ✅ Done — **Verify** | `docker compose up --build` |
| CI (lint → test → build) | ✅ Done | `ci-cd.yml`, matrix build for 3 images, buildx cache |
| Image publishing | ✅ Done (GHCR) | Tags: `latest` (default branch), short SHA, branch name |
| K8s manifests | ✅ Done — **Verify** | Deployment/Service per app + NGINX Ingress; RollingUpdate, probes, limits, securityContext |
| Local K8s on Minikube | 🟡 Claimed, no evidence in repo | Needs screenshots/log evidence |
| Continuous **deployment** | ❌ Missing | Pipeline stops at image push |
| Image/IaC/dependency scanning | ❌ Missing | Trivy listed under "Future Enhancements" |
| HPA, metrics | ❌ Missing | Listed under "Future Enhancements" |
| Terraform / AWS / EKS / ECR / OIDC | ❌ Missing | Only a line in "Future Enhancements" |
| Remote state | ❌ Missing | |
| Observability | ❌ Missing | |
| AWS docs, architecture diagram, cost notes | ❌ Missing | |

### Issues found in the current repo (fix early, they are cheap)

1. **Workflow-level `packages: write`.** The `lint` and `test` jobs inherit write access to packages they never use. Set `permissions: contents: read` at the top and grant `packages: write` only on the build job.
2. **README claims "multi-arch" images, but the workflow sets no `platforms:`.** Either add `platforms: linux/amd64,linux/arm64` (slower builds, Docker Buildx + QEMU) or correct the README. For an x86 EKS node group, `linux/amd64` is enough, so correcting the README is the simpler choice.
3. **Mutable tags.** `latest` and the branch tag move. Deployments must reference an immutable tag (the SHA tag) only.
4. **Actions pinned to major tags** (`@v4`, `@v5`). Acceptable now; pin to commit SHAs and let Dependabot update them once the pipeline starts touching AWS.
5. **Workflow triggers on `main` and `master`**, but the repo only has `master`. Harmless; decide on one default branch and rename if you prefer `main`.
6. **Ingress rewrite behaviour — verify.** `rewrite-target: /$2` strips the `/api` prefix, so `GET /api/health` → `/health` works. But the API service's real routes are `/api/data`, `/api/stats`, so they would be reached at `/api/api/data`. Test this; if confirmed, either document it or adjust the paths.
7. **Image names vs registry.** Manifests must reference `ghcr.io/aswinarun321/<name>-service:<sha>`. If GHCR packages are private (the default for a first push), a cluster without an `imagePullSecret` gets `ImagePullBackOff`. This matters for EKS (see decision D1).
8. **Secrets.** Demo users are documented in the README, which is fine for a demo. Confirm the JWT signing key is **not hard-coded** in `auth/app/main.py` and is read from an environment variable supplied by a Kubernetes Secret (never committed).
9. **No end-to-end check.** Tests are unit tests only. Nothing in CI proves the containers start and answer `/health`. Add a Compose smoke test.
10. **No tests for the Kubernetes or Terraform code.** Add manifest validation (`kubeconform`) and Terraform `fmt`/`validate` to CI.

---

## 2. Decisions to lock in before building

| # | Decision | Recommendation | Why |
|---|---|---|---|
| D1 | **Registry for AWS** | Keep GHCR for the current pipeline. For EKS, **add ECR and cut over** (do not dual-publish long term). | ECR keeps nodes pulling via their IAM role: no pull secrets, no public packages, and it shows IAM/OIDC skills. GHCR works if you make packages public, which is a valid shortcut but a weaker AWS story. |
| D2 | **Kubernetes packaging** | Plain manifests + **Kustomize** overlays (`base`, `minikube`, `eks`). Skip Helm for now. | Manifests already exist. Kustomize is built into `kubectl`, gives clean image-tag substitution, and avoids rewriting everything into a chart. |
| D3 | **Deployment method** | **Direct deploy from GitHub Actions** using OIDC → IAM role → EKS access entry. Skip Argo CD. | Smallest complete path. Mention GitOps as a future extension. |
| D4 | **Who runs `terraform apply`** | **You, locally**, from a reviewed plan. CI runs `fmt`, `validate`, `plan` (read-only role) only. | Giving CI a role that can create IAM and EKS is a large blast radius for a learning project. Apply-from-CI can be an extension behind a protected GitHub Environment. |
| D5 | **Worker node placement** | **Demo mode:** 2 AZs, public subnets, small node group, restrictive security groups, no NAT Gateway. Document private-subnet + NAT as the "production" variant. | A NAT Gateway bills hourly plus per-GB. EKS requires subnets in at least two AZs. |
| D6 | **Ingress on EKS** | **Verify the current status of `ingress-nginx` first.** The Kubernetes project announced its retirement in 2026. Prefer the **AWS Load Balancer Controller (ALB)**, or use `kubectl port-forward` for the demo to avoid load-balancer cost. | Avoid building on a retired component. An ALB bills hourly, so create it only for the demo window. |
| D7 | **Region** | One region for everything, e.g. `ap-south-1` (Mumbai) for lowest latency from Kerala. Confirm service availability and pricing. | Keeps state, ECR and EKS together; simplifies cleanup. |
| D8 | **Terraform state locking** | S3 backend with **`use_lockfile = true`** (native S3 locking, Terraform ≥ 1.10/1.11). Do not add a DynamoDB table. | DynamoDB-based locking is deprecated in favour of S3 native locking. Check the current Terraform docs for your installed version. |

Write the chosen answers into `docs/DECISIONS.md` (one line each, with date).

---

## 3. Target architecture

```text
Developer ── git push / PR ──► GitHub (master, protected)
                                  │
              ┌───────────────────┴────────────────────┐
              ▼                                        ▼
   PR checks (no AWS creds needed)           Push to master
   ruff · pytest · compose smoke test        ruff · pytest · build
   kubeconform · terraform fmt/validate      Trivy (fs + image) · push
   Trivy config · gitleaks                         │
   terraform plan (read-only OIDC role)            │  OIDC (short-lived creds)
                                                   ▼
                                       IAM role: ecr-push (repo+branch scoped)
                                                   ▼
                                           Amazon ECR (immutable SHA tags)
                                                   │
                       protected GitHub Environment "dev" (manual approval)
                                                   │  OIDC
                                       IAM role: eks-deploy (namespace-scoped)
                                                   ▼
        AWS VPC (2 AZ) ──► EKS ──► Namespace "microservices"
                                    ├─ auth-service (2)  ┐
                                    ├─ api-service  (2)  ├─ ClusterIP + HPA + PDB
                                    └─ worker-service (1)┘
                                                   ▲
                                         ALB / port-forward (demo only)

State: S3 bucket (versioned, encrypted, public access blocked, native lockfile)
Local dev path: Docker Compose → Minikube/kind (unchanged, stays the default)
```

### Operating modes

| Mode | When | AWS cost |
|---|---|---|
| **Local-first (default)** | All app, manifest and CI work | None |
| **Short-lived AWS demo** | Prove Terraform + EKS + CD, capture evidence, destroy the same day | EKS control plane (about $0.10/hour on standard support; verify current pricing) + nodes + any ALB/NAT/EBS |
| **Advanced (optional)** | Private nodes + NAT, ALB + TLS, Prometheus/Grafana, Argo CD | Higher; only if you want it |

Do not create EKS to test YAML or app code. Do not leave it running overnight.

---

## 4. Roadmap

| Phase | Name | Effort | Output |
|---|---|---|---|
| 0 | Verify baseline and fix README/ingress gaps | 0.5 day | `docs/PROJECT-STATUS.md`, evidence |
| 1 | Harden CI (permissions, scans, smoke test) | 1 day | Safer pipeline, README badges truthful |
| 2 | Harden Kubernetes manifests + Kustomize + local validation | 1–2 days | `k8s/base`, `k8s/overlays/*`, HPA/PDB/NetworkPolicy |
| 3 | AWS account + budget + CLI | 0.5 day | Budget alerts, SSO/IAM user |
| 4 | Terraform foundation + S3 state bootstrap | 1 day | Remote state |
| 5 | Network module | 1 day | VPC/subnets |
| 6 | ECR + IAM + GitHub OIDC | 1–2 days | Registry + two scoped roles |
| 7 | EKS cluster | 1–2 days | Cluster + nodes |
| 8 | Deploy app to EKS | 1 day | Running workloads |
| 9 | CD pipeline | 1–2 days | Push → ECR → approved deploy |
| 10 | Observability (minimal) | 1 day | Metrics, logs, HPA working |
| 11 | Cleanup, cost report, rehearse teardown/recreate | 0.5 day | Verified destroy |
| 12 | Documentation + portfolio packaging | 1–2 days | README, diagram, screenshots |

**Estimated total:** about 2–3 weeks part-time. Phases 0–2 need no AWS spend at all and deliver visible improvements immediately. Do them first.

---

## Phase 0 — Verify the baseline (no AWS)

**Goal:** Turn the "Verify" items into facts and record them.

```powershell
git pull
python -m venv venv ; .\venv\Scripts\activate
pip install -r requirements.txt
ruff check .
pytest -v

docker compose config --quiet
docker compose up -d --build
docker compose ps
foreach ($p in 5001,5002,5003) { Invoke-RestMethod "http://localhost:$p/health" }
docker compose down
```

Then Minikube:

```powershell
minikube start
minikube addons enable ingress
kubectl apply -f k8s/
kubectl get pods,svc,ingress
$ip = minikube ip
curl "http://$ip/auth/health" ; curl "http://$ip/api/health" ; curl "http://$ip/worker/health"
curl "http://$ip/api/api/data"      # tests the rewrite behaviour (issue 6)
```

Inspect these files and note findings in `docs/PROJECT-STATUS.md`: the three Dockerfiles, `docker-compose.yml`, each `k8s/*-deployment.yaml` (image reference, tag, env vars, probes, securityContext, resources), `requirements.txt` pinning, and the existing `plan.md`.

Do not print `.env`, kubeconfig or tokens.

**Acceptance**
- [ ] 23 tests and Ruff pass locally.
- [ ] Compose stack healthy; Minikube deploy works; screenshots saved in `docs/screenshots/`.
- [ ] Ingress path behaviour confirmed and documented (or fixed).
- [ ] Image references and tags in manifests recorded.
- [ ] JWT secret source confirmed (env var, not source code).
- [ ] The table in section 1 updated with real results.

**Commit:** `docs: record verified project baseline`

---

## Phase 1 — Harden CI (no AWS)

Edit `.github/workflows/ci-cd.yml` (keep the existing structure; extend it).

1. **Least-privilege permissions.** Top level `permissions: contents: read`; on `build-and-push` only: `contents: read`, `packages: write`.
2. **Concurrency** to cancel superseded runs: `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }`.
3. **Compose smoke test job** (after lint/test): `docker compose up -d --build`, poll the three `/health` endpoints with a timeout, dump logs on failure, `docker compose down -v`.
4. **Trivy**
   - Filesystem/IaC scan (`trivy fs .` / `trivy config .`) on every PR.
   - Image scan on the built image (fail on `CRITICAL` fixed vulnerabilities; start with report-only if it is noisy).
5. **Secret scanning** with `gitleaks` on PRs.
6. **Dependency audit:** `pip-audit -r requirements.txt` (and each service's `requirements.txt`).
7. **Manifest validation:** `kubeconform -strict` over `k8s/`.
8. **Dependabot** (`.github/dependabot.yml`) for `github-actions`, `pip` (each service directory) and `docker`.
9. **Branch protection** on `master`: require the CI checks and a PR before merge.
10. **Image tags:** keep the SHA tag; remove the dependence on `latest`/branch tags for deployment. Decide on multi-arch (issue 2) and fix the README.
11. Pin third-party actions to commit SHAs once Dependabot is in place.

**Acceptance**
- [ ] PR runs: lint, test, smoke test, scans, manifest validation.
- [ ] Only the build job has `packages: write`.
- [ ] Branch protection enforces the checks.
- [ ] README no longer claims features the pipeline does not have.

**Commits:** `ci: least-privilege permissions and concurrency`, `ci: add compose smoke test`, `ci: add trivy, gitleaks and pip-audit`, `ci: validate kubernetes manifests`

---

## Phase 2 — Harden Kubernetes manifests (local only)

Restructure into Kustomize without changing behaviour:

```text
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── auth-deployment.yaml  auth-service.yaml
│   ├── api-deployment.yaml   api-service.yaml
│   ├── worker-deployment.yaml worker-service.yaml
│   ├── hpa.yaml  pdb.yaml  networkpolicy.yaml
│   └── ingress.yaml
└── overlays/
    ├── minikube/kustomization.yaml     # nginx ingress, GHCR images
    └── eks/kustomization.yaml          # ECR image names/tags, ALB ingress
```

Tasks:
1. Add a **namespace** (`microservices`) instead of `default`.
2. **Secret handling:** `JWT_SECRET` from a Kubernetes Secret created out-of-band (`kubectl create secret generic ...` for local; Secrets Manager/External Secrets as an extension). Commit only a `secret.example.yaml` with placeholders.
3. Add `readOnlyRootFilesystem: true` (with an `emptyDir` for `/tmp` if needed), `seccompProfile: RuntimeDefault`, and `automountServiceAccountToken: false` where the app does not call the API.
4. Add a **startupProbe** if cold start is slow, and confirm readiness vs liveness use sensible paths and timings.
5. Add **HPA** for `auth` and `api` (CPU target ~70%, min 2, max 4). Minikube needs `minikube addons enable metrics-server`; EKS needs metrics-server installed.
6. Add **PodDisruptionBudgets** (`minAvailable: 1`) for 2-replica services.
7. Add a **default-deny NetworkPolicy** plus explicit allows (ingress → services; `api`/`worker` → `auth` only if needed). Note: Minikube's default CNI may not enforce NetworkPolicy; EKS needs a policy-capable setup (VPC CNI network policy support or Calico). Treat as best-effort locally.
8. Use a Kustomize `images:` block so the tag is set in one place:

```yaml
# k8s/overlays/eks/kustomization.yaml (example — match the exact image names in your manifests)
resources: [../../base]
images:
  - name: ghcr.io/aswinarun321/api-service
    newName: <account-id>.dkr.ecr.<region>.amazonaws.com/api-service
    newTag: <git-sha>
```

**Acceptance**
- [ ] `kubectl kustomize k8s/overlays/minikube | kubeconform -strict` passes.
- [ ] `kubectl apply -k k8s/overlays/minikube` brings all pods Ready.
- [ ] Rolling update and `kubectl rollout undo` rehearsed and documented.
- [ ] HPA shows real CPU metrics; a simple load test scales `api` up.
- [ ] No plaintext secret in Git.

**Commits:** `refactor(k8s): move manifests to kustomize base and overlays`, `feat(k8s): add hpa, pdb and networkpolicy`, `security(k8s): tighten pod security context`

---

## Phase 3 — AWS account and CLI

1. Use a dedicated AWS account. Root user: MFA on, no access keys.
2. Create an admin identity for yourself (IAM Identity Center/SSO preferred, otherwise an IAM user with MFA). Never use root for work.
3. Install AWS CLI v2; `aws configure sso` (or `aws configure`).
4. **Create an AWS Budget** (e.g., a low monthly cap with alerts at 50%/80%/100%) *before* any resource. Enable Cost Explorer.
5. Pick the region (D7) and check service quotas for EC2 vCPUs and EKS.

```powershell
aws --version
aws sts get-caller-identity
aws configure get region
```

**Acceptance**
- [ ] `get-caller-identity` shows the intended account.
- [ ] Budget alerts delivered to your email.
- [ ] No credentials in the repo or in chat.

---

## Phase 4 — Terraform foundation and remote state

**Layout** (adapt as you go; avoid modules that only wrap one resource):

```text
terraform/
├── bootstrap/                # S3 state bucket; applied once, local state
├── modules/
│   ├── network/
│   ├── ecr/
│   ├── github-oidc/
│   └── eks/
└── envs/
    └── dev/
        ├── backend.tf
        ├── versions.tf
        ├── providers.tf
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars.example
```

**Bootstrap** creates one S3 bucket with versioning, server-side encryption (SSE-S3 or KMS), all four public-access blocks on, and a bucket policy that denies non-TLS access. Apply it once with local state; its small local state file stays out of Git (consider keeping it only on your machine).

**Backend for `envs/dev`:**

```hcl
terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }   # pin to the major you test
  }
  backend "s3" {
    bucket       = "<your-state-bucket>"
    key          = "dev/terraform.tfstate"
    region       = "<region>"
    encrypt      = true
    use_lockfile = true     # native S3 locking
  }
}
```

Add to `.gitignore`: `*.tfstate*`, `.terraform/`, `*.tfplan`, `*.tfvars` (keep `*.tfvars.example`), `crash.log`, `kubeconfig*`.

Add a **default tag set** in the provider (`default_tags { tags = { Project = "microservice-cicd-kubernetes", Env = "dev", ManagedBy = "terraform" } }`). Tags make the post-destroy leftover check much easier.

**Acceptance**
- [ ] `terraform fmt -check -recursive`, `init`, `validate` pass.
- [ ] State lives in S3; a second `plan` shows no changes.
- [ ] Locking verified (open a second `plan` while one is held, or confirm the `.tflock` object appears).
- [ ] CI runs `fmt` and `validate` (`terraform init -backend=false`).

**Commits:** `chore(terraform): add foundation and bootstrap`, `feat(terraform): remote state backend`

---

## Phase 5 — Network module

Resources: VPC, 2 public subnets across 2 AZs, Internet Gateway, route tables, security groups. Add the Kubernetes discovery tags (`kubernetes.io/role/elb = 1` on public subnets, plus `kubernetes.io/cluster/<name> = shared`). **No NAT Gateway in demo mode.** Add an input variable `enable_private_subnets` / `enable_nat` (default `false`) so the production variant is a one-line change, and document the extra cost.

Choose a CIDR that does not overlap other networks you use (e.g., `10.20.0.0/16`).

**Acceptance**
- [ ] `terraform plan` reviewed line by line.
- [ ] Outputs: `vpc_id`, `public_subnet_ids`.
- [ ] No `0.0.0.0/0` inbound on anything except what is deliberately public.
- [ ] Network diagram in `docs/ARCHITECTURE.md`.

---

## Phase 6 — ECR and GitHub OIDC

**ECR:** one repository per service (`auth-service`, `api-service`, `worker-service`), `image_tag_mutability = "IMMUTABLE"`, scan on push, lifecycle policy (keep last ~10 images), encryption on.

**GitHub OIDC provider:** `token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.

**Two separate roles** (this is the main security improvement over a single CI role):

| Role | Used by | Trust (`sub` claim) | Permissions |
|---|---|---|---|
| `gha-ecr-push` | Build job on `master` | `repo:AswinArun321/microservice-cicd-kubernetes:ref:refs/heads/master` | ECR push to the three repos only |
| `gha-eks-deploy` | Deploy job | `repo:AswinArun321/microservice-cicd-kubernetes:environment:dev` | `eks:DescribeCluster` on the one cluster; Kubernetes permissions come from the EKS access entry, not IAM |
| `gha-tf-plan` (optional) | PR `terraform plan` | `repo:AswinArun321/microservice-cicd-kubernetes:pull_request` | Read-only + state bucket read |

Trust policy condition pattern:

```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:AswinArun321/microservice-cicd-kubernetes:environment:dev"
  }
}
```

Note: a job that declares `environment: dev` emits the `environment:` form of `sub`, not the `ref:` form, so match whichever your job actually uses. Never use a wildcard that would let forks or any branch assume the role.

Store the role ARNs as GitHub **repository variables** (they are not secrets). **No AWS access keys anywhere.**

**Acceptance**
- [ ] Repos exist with immutable tags and lifecycle rules.
- [ ] A test workflow assumes `gha-ecr-push` and pushes one image.
- [ ] A workflow on another branch or a fork **fails** to assume the role (test this on purpose).
- [ ] Role policies reviewed for least privilege.

---

## Phase 7 — EKS cluster

1. Choose a Kubernetes version that is in **standard support** (extended support costs more); check the EKS version calendar.
2. Cluster IAM role and node IAM role (`AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`).
3. Managed node group: 2 small nodes (e.g., `t3.medium` class; verify availability and pricing in your region), 1 desired for the cheapest demo if resources allow, `min=1`, `max=3`, AL2023 AMI.
4. API endpoint: public access restricted to **your current IP/32** (`public_access_cidrs`), private access on. Update the CIDR if your ISP changes your IP.
5. **Authentication mode `API`** with **access entries** (not the legacy `aws-auth` ConfigMap):
   - your admin identity → cluster admin policy;
   - `gha-eks-deploy` → an access policy scoped to the `microservices` namespace (e.g., `AmazonEKSEditPolicy` with namespace scope).
6. Enable control-plane logging for only `api` and `audit` at first (log ingestion costs money; set a short CloudWatch retention).
7. Core add-ons: VPC CNI, CoreDNS, kube-proxy; install **metrics-server** for the HPA.
8. If using the ALB controller (D6): install it with Helm and an IAM role via **EKS Pod Identity** or IRSA, with the controller's IAM policy.

```powershell
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl get nodes
kubectl get pods -A
```

**Acceptance**
- [ ] Cluster Active, nodes Ready, system pods healthy.
- [ ] API endpoint limited to your IP.
- [ ] Access entries work for you and for the deploy role; the deploy role cannot touch other namespaces.
- [ ] `terraform destroy` of the EKS module alone succeeds (rehearse destroy early, not at the end).

---

## Phase 8 — Deploy the application to EKS

1. Push one set of images to ECR (via the Phase 6 workflow or manually for the first run).
2. Create the namespace and Secret:

```powershell
kubectl create namespace microservices
kubectl create secret generic app-secrets -n microservices --from-literal=JWT_SECRET=<generated-value>
```

3. Set the EKS overlay's image names/tags and apply:

```powershell
kubectl apply -k k8s/overlays/eks
kubectl rollout status deployment/api-deployment -n microservices
kubectl get pods,svc,hpa -n microservices
```

4. Reach the app: `kubectl port-forward` first; create the ALB ingress only when you need the public demo.
5. Run the smoke test script (`scripts/smoke-test.ps1`): health endpoints, a login that returns a token, `/verify` on that token, one `api` read, one worker job.

**Acceptance**
- [ ] All pods Ready; service-to-service calls work.
- [ ] Smoke test passes; screenshots captured.
- [ ] Rollout, failed-rollout and `rollout undo` demonstrated once.

---

## Phase 9 — Continuous deployment

Add a `deploy` job (or a separate `deploy-dev.yml`) after `build-and-push`:

```yaml
deploy:
  needs: build-and-push
  if: github.ref == 'refs/heads/master' && github.event_name == 'push'
  runs-on: ubuntu-latest
  environment: dev            # required reviewers = manual approval
  permissions:
    id-token: write
    contents: read
  steps:
    - uses: actions/checkout@<pinned-sha>
    - uses: aws-actions/configure-aws-credentials@<pinned-sha>
      with:
        role-to-assume: ${{ vars.AWS_EKS_DEPLOY_ROLE_ARN }}
        aws-region: ${{ vars.AWS_REGION }}
    - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }} --region ${{ vars.AWS_REGION }}
    - run: |
        cd k8s/overlays/eks
        kustomize edit set image <image-name>=<ecr-uri>:${{ github.sha }}   # one line per service
        kubectl apply -k .
        kubectl rollout status deployment/api-deployment -n microservices --timeout=180s
        # repeat for auth and worker
    - run: ./scripts/smoke-test.sh
    - if: failure()
      run: kubectl rollout undo deployment/api-deployment -n microservices   # per deployment
```

Rules:
- The build job pushes to ECR using `gha-ecr-push`; the deploy job uses a different role.
- Deployments reference the **commit SHA** only.
- Because the cluster only exists during demos, make deploy **manual (`workflow_dispatch`) or skipped when `EKS_CLUSTER_NAME` is unset**, so a normal push does not fail when the cluster is destroyed. Keep Minikube-based validation as the always-on safety net.
- Do not print kubeconfig or tokens in logs.

**Acceptance**
- [ ] Push → tests → image in ECR → approval → rollout → smoke test.
- [ ] A deliberately broken image triggers rollback and a red pipeline.
- [ ] No AWS key exists in repository secrets.

---

## Phase 10 — Observability (minimal)

Must have:
- `kubectl top` working through metrics-server; HPA scales under load.
- Application logs readable with `kubectl logs`; structured log lines with timestamp and request context (check what the services emit).
- `/health` checks wired to probes.
- CI/CD status badges; AWS billing visible in Cost Explorer.

Choose **one** optional extension:
- CloudWatch Container Insights (simplest on AWS, but ingestion costs), **or**
- Prometheus + Grafana via Helm, with `/metrics` added to each FastAPI service (e.g., `prometheus-fastapi-instrumentator`) and one dashboard + one tested alert. (Matches the README's stated future work.)

**Acceptance**
- [ ] Resource and health data inspectable.
- [ ] One dashboard screenshot (if the optional extension is used).
- [ ] Troubleshooting steps recorded.

---

## Phase 11 — Cleanup, cost report, reproducibility

Before every demo: note the time, expected cost and the plan output.

After the demo:
1. Capture evidence (screenshots, outputs, workflow runs).
2. Delete Kubernetes-created AWS resources first (the ALB/target groups/security groups created by the controller are **not** in Terraform state): `kubectl delete ingress -A --all` and wait, or `kubectl delete -k k8s/overlays/eks`.
3. `terraform plan -destroy`, then `terraform destroy` in `envs/dev`.
4. Verify nothing billable remains:

```powershell
aws eks list-clusters --region <region>
aws ec2 describe-nat-gateways --region <region> --filter Name=state,Values=available
aws elbv2 describe-load-balancers --region <region>
aws ec2 describe-volumes --region <region> --filters Name=status,Values=available
aws ec2 describe-addresses --region <region>
aws logs describe-log-groups --region <region> --log-group-name-prefix /aws/eks
```

   Also tag-search with the `Project` tag via the Resource Groups Tagging API or the AWS Tag Editor.
5. Keep the state bucket and ECR repos (cheap) or destroy them deliberately. Destroy the **environment before** the state bucket.
6. Write `docs/COST-AND-CLEANUP.md`: what each run created, how long it ran, the observed cost, and the retained resources.
7. **Rehearse recreation**: destroy and rebuild once from the documented steps; time it.

**Acceptance**
- [ ] Clean-slate check passes; next-day Cost Explorer shows no ongoing charges.
- [ ] Recreate-from-scratch steps proven.

---

## Phase 12 — Documentation and portfolio

Update `README.md` (it already has strong local/CI/K8s sections; add rather than rewrite):

1. Architecture diagram for **both** paths: local and AWS.
2. AWS prerequisites, region, cost warning, and teardown section near the top.
3. Terraform usage: bootstrap → `init` → `plan` → `apply` → `destroy`.
4. CI/CD description including OIDC, the two roles, the approval gate, and the security scans.
5. Security controls (pod hardening, OIDC, scoped roles, scanning, no long-lived keys).
6. Evidence section with screenshots (no secrets, no account IDs if you prefer to blur them).
7. Honest "Known limitations" (public nodes in demo mode, single environment, manual `terraform apply`).
8. Update "Future Enhancements" with only what is truly left (Argo CD, private nodes + NAT, TLS/ACM + Route 53, multi-env, Secrets Manager integration).
9. Fix the README items from section 1 (multi-arch claim, ingress paths).
10. Add repository description and topics on GitHub.

```text
docs/
├── PROJECT-STATUS.md   ├── DECISIONS.md      ├── ARCHITECTURE.md
├── SETUP.md            ├── DEPLOYMENT.md     ├── SECURITY.md
├── COST-AND-CLEANUP.md ├── TROUBLESHOOTING.md ├── INTERVIEW-NOTES.md
└── screenshots/
```

`INTERVIEW-NOTES.md` should answer, in your own words: why OIDC over access keys; why two roles; why immutable tags; why apply is manual; what a NAT Gateway costs and why you avoided it; how rollback works; what you would change for production.

---

## 5. Definition of done

**Application / CI**
- [ ] Local stack and Minikube deployment verified with evidence.
- [ ] CI has least-privilege permissions, smoke test, Trivy, gitleaks, pip-audit, manifest validation.
- [ ] Branch protection on `master`.

**Terraform / AWS**
- [ ] Formatted, validated, versions pinned; state remote, encrypted, locked.
- [ ] Network, ECR, OIDC roles and EKS provisioned from code; every apply preceded by a reviewed plan.
- [ ] No state, plans, tfvars, kubeconfig or secrets in Git.
- [ ] Destroy and recreate proven.

**Delivery / security**
- [ ] OIDC only; no long-lived AWS keys; role trust verified to reject other branches/forks.
- [ ] Immutable SHA tags; approval gate; automatic rollback on failure.
- [ ] Pod hardening, HPA, PDB and NetworkPolicy in place.

**Docs**
- [ ] README, diagram, screenshots, cost report, troubleshooting and interview notes complete.

---

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Surprise AWS bill | Budget + alerts first; same-day destroy; leftover-resource checks |
| Orphaned ALB/ENIs block VPC destroy | Delete the ingress/controller resources before `terraform destroy` |
| Locked out of the cluster after your IP changes | Keep the private endpoint on; update `public_access_cidrs`; keep an admin access entry |
| Over-broad OIDC trust | Exact `sub` match; test that other branches and forks are rejected |
| CI fails when the demo cluster is gone | Make deploy manual/conditional; Minikube checks remain the baseline |
| Retired or changing components (ingress-nginx, EKS versions) | Check current docs before choosing; pin versions |
| State loss/corruption | Bucket versioning; never edit state by hand; never delete the bucket first |
| Scope creep | Finish phases 0–2 and 4–9 before any optional extension |

---

## 7. Working method and commit sequence

For each phase: inspect → implement only that phase → validate → update `docs/PROJECT-STATUS.md` → commit → proceed only when acceptance criteria pass. Use a feature branch and PR per phase so the CI you built is exercised.

```text
docs: record verified project baseline
ci: least-privilege permissions and concurrency
ci: add compose smoke test
ci: add trivy, gitleaks and pip-audit
refactor(k8s): move manifests to kustomize base and overlays
feat(k8s): add hpa, pdb and networkpolicy
chore(terraform): add foundation and bootstrap
feat(terraform): remote state backend
feat(terraform): network module
feat(terraform): ecr and github oidc roles
feat(terraform): eks cluster
feat(k8s): eks overlay
feat(cd): deploy to eks with approval and rollback
feat(observability): metrics and dashboards
docs: architecture, deployment, security and cost guides
```

---

## 8. Immediate next actions (all free, all local)

1. Run the Phase 0 commands and fill in `docs/PROJECT-STATUS.md`.
2. Open the Dockerfiles, `docker-compose.yml` and `k8s/*-deployment.yaml`; check image names, JWT secret handling and probes.
3. Test the ingress `/api/api/data` behaviour.
4. Make the Phase 1 permission fix and README correction in one small PR.
5. Create the AWS Budget before touching Terraform.

**Do not run `terraform apply` or create EKS until Phases 0–2 pass.**

---

## 9. Reference documentation

Check these for current syntax, supported versions, support windows and pricing:

- Terraform S3 backend (locking): https://developer.hashicorp.com/terraform/language/backend/s3
- Terraform AWS provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Amazon EKS user guide, access entries, versions: https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html
- Amazon EKS pricing: https://aws.amazon.com/eks/pricing/
- AWS Load Balancer Controller: https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- GitHub OIDC with AWS: https://docs.github.com/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
- Amazon ECR: https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html
- Kustomize: https://kubectl.docs.kubernetes.io/references/kustomize/
- Trivy: https://trivy.dev/
- AWS Pricing Calculator: https://calculator.aws/
