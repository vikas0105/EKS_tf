#!/bin/bash
set -e

# ============================================
# Bootstrap: install Terraform if needed,
# verify remote state is reachable, connect.
# ============================================
# main.tf has the real S3 backend values (bucket/region/table) hardcoded
# for this AWS account, so this script's only jobs are:
#   1. Install Terraform if it's missing
#   2. Verify the state bucket + lock table are reachable (READ-ONLY —
#      this never creates them; they already exist)
#   3. Run `terraform init`
#
# Usage: ./bootstrap.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================
# Check for Terraform, install if missing
# ============================================
install_terraform() {
  echo "Terraform not found — installing..."
  echo ""

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
  else
    OS_ID="unknown"
  fi

  case "$OS_ID" in
    amzn)
      # Amazon Linux 2 and 2023
      if command -v dnf &>/dev/null; then
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
        sudo dnf install -y terraform
      else
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
        sudo yum install -y terraform
      fi
      ;;
    ubuntu|debian)
      sudo apt-get update -y
      sudo apt-get install -y gnupg software-properties-common curl
      curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs 2>/dev/null || echo focal) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
      sudo apt-get update -y
      sudo apt-get install -y terraform
      ;;
    *)
      # Generic fallback: download the binary directly
      echo "Unrecognized OS ($OS_ID) — installing Terraform binary directly..."
      TF_VERSION="1.9.8"
      TMP_DIR=$(mktemp -d)
      curl -sSL -o "${TMP_DIR}/terraform.zip" \
        "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
      unzip -q "${TMP_DIR}/terraform.zip" -d "${TMP_DIR}"
      sudo mv "${TMP_DIR}/terraform" /usr/local/bin/terraform
      rm -rf "${TMP_DIR}"
      ;;
  esac

  if command -v terraform &>/dev/null; then
    echo -e "${GREEN}Terraform installed: $(terraform version | head -n1)${NC}"
  else
    echo -e "${RED}Terraform installation failed — install manually and re-run this script${NC}"
    exit 1
  fi
  echo ""
}

if command -v terraform &>/dev/null; then
  echo -e "${GREEN}Terraform already installed: $(terraform version | head -n1)${NC}"
  echo ""
else
  install_terraform
fi

echo "=========================================="
echo "  Connecting to Terraform Remote State"
echo "=========================================="
echo ""

# ----- Fixed values (this account's state bucket already exists) -----
# main.tf has these same values hardcoded in its backend "s3" {} block,
# so this script does not create or auto-detect anything — it only
# verifies the bucket/table are reachable, then runs terraform init.
#
# (An earlier version of this script tried to auto-detect/auto-create
# the bucket on every run. That was removed: a transient failure in the
# detection step could cause it to attempt creating a bucket that
# already existed, which AWS correctly rejects with a confusing error.
# Since the bucket is known to already exist, creation is never needed
# again — only a read-only reachability check.)
BUCKET="eks-tf-state-157328692630"
TABLE="eks-tf-locks"
REGION="ap-south-1"

echo "Bucket:  $BUCKET"
echo "Table:   $TABLE"
echo "Region:  $REGION"
echo ""

# ----- Verify the bucket is reachable (read-only, never creates anything) -----
echo "Verifying state bucket is reachable..."
if aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>/tmp/bootstrap_bucket_err; then
  echo -e "${GREEN}Bucket reachable${NC}"
else
  echo -e "${RED}Could not reach bucket '${BUCKET}' in region '${REGION}'${NC}"
  echo ""
  echo "Actual AWS error:"
  cat /tmp/bootstrap_bucket_err
  echo ""
  echo "This script does not auto-create the bucket, since it should"
  echo "already exist. Troubleshooting steps:"
  echo "  1. List your buckets:   aws s3api list-buckets --query \"Buckets[].Name\""
  echo "  2. Confirm its region:  aws s3api get-bucket-location --bucket ${BUCKET}"
  echo "  3. Check IAM permissions for s3:GetObject / s3:ListBucket on this bucket"
  rm -f /tmp/bootstrap_bucket_err
  exit 1
fi
rm -f /tmp/bootstrap_bucket_err
echo ""

# ----- Verify the DynamoDB lock table is reachable (read-only) -----
echo "Verifying lock table is reachable..."
if aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" &>/dev/null; then
  echo -e "${GREEN}Table reachable${NC}"
else
  echo -e "${RED}Could not reach table '${TABLE}' in region '${REGION}'${NC}"
  echo ""
  echo "This script does not auto-create the table, since it should"
  echo "already exist. Check IAM permissions for dynamodb:DescribeTable."
  exit 1
fi

# ----- Connect Terraform to this backend -----
# main.tf has the real bucket/key/region/table values hardcoded, so a
# plain `terraform init` works correctly with zero flags — including
# if you (or anyone) ever runs `terraform init` directly instead of
# this script.
echo ""
echo "Running terraform init..."
echo ""

terraform init -reconfigure

echo ""
echo "=========================================="
echo -e "${GREEN}Connected to remote state${NC}"
echo "=========================================="
echo ""
echo "Next:"
echo "  terraform plan     (shows 'no changes' if the cluster already exists)"
echo "  terraform apply    (creates it, or applies any new changes)"
echo ""
