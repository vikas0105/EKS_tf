# EKS Terraform — Clone and Run

Deploys: EKS v1.36 (private) + managed node group (t3.medium, AL2023) + AWS Load Balancer Controller (via Helm/IRSA).

**You never need to commit anything after your initial upload.** State lives in S3 with DynamoDB locking. If a CloudShell session expires, just open a new one, clone again, and continue — it reconnects to the exact same state automatically.

---

## Prerequisites

- AWS credentials configured (CloudShell has this built in already)
- Terraform, kubectl, helm — all pre-installed in CloudShell

---

## Deploy

```bash
git clone https://github.com/YOUR_USERNAME/eks-terraform.git
cd eks-terraform
cp terraform.tfvars.example terraform.tfvars

chmod +x bootstrap.sh
./bootstrap.sh

terraform apply
```

Type `yes` when prompted. Takes ~20-25 minutes.

That's the entire flow. No file edits, no git commits, no manual bucket setup beyond what `bootstrap.sh` does for you automatically.

---

## If your CloudShell session expires (new session, same or different day)

Run the exact same commands again:

```bash
git clone https://github.com/YOUR_USERNAME/eks-terraform.git
cd eks-terraform
cp terraform.tfvars.example terraform.tfvars

chmod +x bootstrap.sh
./bootstrap.sh

terraform plan     # shows "no changes" — confirms it found your existing cluster
```

Nothing was lost. `bootstrap.sh` detects the S3 bucket and DynamoDB table already exist (it created them the first time) and just reconnects Terraform to them. You can now run `terraform apply`, `terraform destroy`, or anything else exactly as before.

**Why this works reliably:** `main.tf` has a permanently empty `backend "s3" {}` block — Terraform's built-in "partial configuration" feature. The real bucket name, region, and table are passed in fresh every time by `bootstrap.sh`, not written into any file. The bucket name itself is deterministic (`eks-tf-state-<your-AWS-account-id>`), so it's identical on every clone, every session, every machine — nothing to remember, nothing to sync, nothing to commit.

---

## After apply finishes

```bash
aws eks update-kubeconfig --region us-east-1 --name $(terraform output -raw eks_cluster_name)

kubectl get nodes
kubectl get pods -n kube-system | grep aws-load-balancer

chmod +x validate.sh && ./validate.sh
```

---

## Destroy when done

```bash
./bootstrap.sh      # reconnect first if this is a new session
terraform destroy
```

The S3 bucket and DynamoDB table are not deleted by `terraform destroy` (they exist outside this Terraform config, by design — deleting them would delete your state history). Delete them manually only if you're fully done with the project:

```bash
aws s3 rb s3://eks-tf-state-$(aws sts get-caller-identity --query Account --output text) --force
aws dynamodb delete-table --table-name eks-tf-locks --region us-east-1
```

---

## Repo contents

```
eks-terraform/
├── main.tf                      # providers + module calls + empty backend "s3" {} block (never changes)
├── variables.tf                 # inputs (region, instance type, sizes...)
├── outputs.tf                   # cluster name, endpoint, VPC id, etc.
├── terraform.tfvars.example     # copy to terraform.tfvars, edit if needed
├── bootstrap.sh                 # run every session: creates/reuses S3+DynamoDB, connects terraform init
├── deploy.sh                    # optional: plan+apply+kubeconfig in one go (run after bootstrap.sh)
├── validate.sh                  # optional: 20+ post-deploy checks
├── Makefile                     # optional: make apply / make destroy / make test
├── .gitignore                   # keeps local state/secrets out of git (not used once backend is remote)
└── modules/
    ├── vpc/              # VPC, 4 subnets, 2 NAT gateways
    ├── eks/              # cluster + OIDC provider
    ├── node_group/       # managed node group
    └── alb_controller/   # IAM role (IRSA) + Helm release
```

---

## Customize (optional)

Edit `terraform.tfvars` before applying:

```hcl
aws_region              = "us-east-1"
cluster_version         = "1.36"
instance_type           = "t3.medium"
capacity_type           = "ON_DEMAND"
node_group_min_size     = 1
node_group_desired_size = 1
node_group_max_size     = 1
```

If you use a region other than `us-east-1`, set it before running `bootstrap.sh` too, so the state bucket is created in the same region:

```bash
export AWS_REGION="us-west-2"
./bootstrap.sh
```

(Do this every session where you're using a non-default region — it's just an environment variable, not a file edit.)

---

## What bootstrap.sh does, every time you run it

1. Checks if the S3 bucket `eks-tf-state-<your-account-id>` exists — creates it (versioned, encrypted, private) only if it doesn't
2. Checks if the DynamoDB table `eks-tf-locks` exists — creates it only if it doesn't
3. Runs `terraform init -reconfigure` with the bucket/table passed in as `-backend-config` flags

Nothing in the repo is ever modified. Safe to run as many times as you want, from as many sessions as you want.
