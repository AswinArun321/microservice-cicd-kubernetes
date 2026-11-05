# Cloud Cost Optimization & Teardown Protocol

This guide outlines cost control mechanisms, hourly pricing breakdowns, and the exact teardown sequence required to ensure zero ongoing cloud spend after demonstrations.

---

## 1. Cost Breakdown & Strategy

To balance **portfolio-grade cloud demonstration** with **budget discipline**, the architecture employs strict cost optimization strategies:

| Component | AWS Resource | Demo Mode | Production Variant | Estimated Cost (ap-south-1) |
|---|---|---|---|---|
| **Control Plane** | Amazon EKS Cluster | Active only during demo (~2-3 hrs) | Continuous | ~$0.10 / hour |
| **Worker Nodes** | EC2 Managed Node Group (2x `t3.medium`) | Active only during demo (~2-3 hrs) | Continuous | ~$0.0416 / hr per node (~$0.083 / hr total) |
| **Networking** | NAT Gateway | **Disabled** (`enable_nat = false`) | 1 NAT Gateway | **$0.00** in Demo Mode (Saves ~$32.40/month baseline) |
| **Ingress** | Application Load Balancer (ALB) | Active only during demo window | Continuous | ~$0.0225 / hour + LCU usage |
| **Registry** | Amazon ECR | 3 Repositories with lifecycle rule (keep 10 images) | Same | ~$0.10 / GB / month (< $0.05 / mo) |
| **State Storage** | Amazon S3 | Single encrypted bucket with native lock | Same | Negligible (< $0.02 / mo) |

> **Typical 2-hour demonstration cost:** Under **$0.50 USD**.

---

## 2. Order of Destruction (Crucial Protocol)

Deleting resources in the incorrect sequence can cause Terraform to hang or fail (e.g., an Application Load Balancer created by the Kubernetes controller will block VPC and subnet deletion if not removed first).

Follow this strict destruction sequence:

### Step 1: Delete Ingress & In-Cluster Cloud Resources
Remove the Kubernetes ingress resource so the AWS Load Balancer Controller deletes the ALB, target groups, and security groups:
```bash
# Delete the EKS overlay or all ingress resources
kubectl delete -k k8s/overlays/eks
# or
kubectl delete ingress -A --all

# Wait 60 seconds for AWS ALB controller to finish deleting the AWS ALB
```

### Step 2: Teardown EKS and VPC Infrastructure with Terraform
```bash
cd terraform/envs/dev

# 1. Generate and review destruction plan
terraform plan -destroy -out=destroy.tfplan

# 2. Execute destruction
terraform apply destroy.tfplan
```

### Step 3: Verify Zero Billable Resources Remain
Run the following audit commands to ensure no orphan resources are incurring charges:

```bash
REGION="ap-south-1"

# 1. Verify EKS clusters
aws eks list-clusters --region $REGION

# 2. Verify NAT Gateways
aws ec2 describe-nat-gateways --region $REGION --filter Name=state,Values=available

# 3. Verify Load Balancers
aws elbv2 describe-load-balancers --region $REGION

# 4. Verify unattached EBS volumes
aws ec2 describe-volumes --region $REGION --filters Name=status,Values=available

# 5. Verify unattached Elastic IPs
aws ec2 describe-addresses --region $REGION

# 6. Verify CloudWatch EKS log groups
aws logs describe-log-groups --region $REGION --log-group-name-prefix /aws/eks
```

On Windows PowerShell:
```powershell
$Region = "ap-south-1"
aws eks list-clusters --region $Region
aws ec2 describe-nat-gateways --region $Region --filter Name=state,Values=available
aws elbv2 describe-load-balancers --region $Region
aws ec2 describe-volumes --region $Region --filters Name=status,Values=available
aws ec2 describe-addresses --region $Region
aws logs describe-log-groups --region $Region --log-group-name-prefix /aws/eks
```

### Step 4: Optional State Bucket & ECR Teardown
If completing a total account wipe:
```bash
# Clean up bootstrap state bucket
cd ../../bootstrap
terraform destroy -auto-approve
```
*(Note: Keep the bootstrap bucket and ECR repositories if you plan to re-run demos, as idle storage costs are mere pennies).*

