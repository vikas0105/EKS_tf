#!/bin/bash
set -e

# ============================================
# Bootstrap + Connect to Remote State
# ============================================
# Run this every time after cloning — in a fresh CloudShell session,
# a new machine, wherever. It's fully idempotent:
#
#   - If the S3 bucket / DynamoDB table don't exist yet, it creates them.
#   - If they already exist, it just reuses them.
#   - Either way, it runs `terraform init` pointed at that same bucket.
#
# The bucket/table names are DETERMINISTIC — derived from your AWS
# account ID, which never changes — so this script always reconnects
# to the exact same state, with zero manual input and zero file edits.
#
# main.tf itself is never modified. Nothing needs to be committed.
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
    echo -e "${GREEN}✓ Terraform installed: $(terraform version | head -n1)${NC}"
  else
    echo -e "${RED}✗ Terraform installation failed — install manually and re-run this script${NC}"
    exit 1
  fi
  echo ""
}

if command -v terraform &>/dev/null; then
  echo -e "${GREEN}✓ Terraform already installed: $(terraform version | head -n1)${NC}"
  echo ""
else
  install_terraform
fi

echo "=========================================="
echo "  Connecting to Terraform Remote State"
echo "=========================================="
echo ""

# ----- Config (deterministic — same every run) -----
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="eks-tf-state-${ACCOUNT_ID}"
TABLE="eks-tf-locks"
KEY="eks/terraform.tfstate"

echo "Account:  $ACCOUNT_ID"
echo "Bucket:   $BUCKET"
echo "Table:    $TABLE"
echo ""

# ----- Discover the bucket's ACTUAL region, if it already exists -----
# Important: this does NOT trust the current session's $AWS_REGION blindly.
# CloudShell sets AWS_REGION based on whichever region is currently selected
# in the console — that can differ between sessions even though the bucket
# itself never moves. S3's ListObjectsV2/backend calls fail with a 301
# redirect if you address the bucket using the wrong region, so we look up
# the real region first and use that for everything below.
#
# Note: this uses the `if VAR=$(cmd); then` form deliberately — assigning
# inside the if-condition is safe under `set -e` (unlike capturing $? on a
# separate line afterward, which causes the whole script to exit silently
# the moment the command returns non-zero, before the next line even runs).
if BUCKET_LOCATION=$(aws s3api get-bucket-location --bucket "$BUCKET" --output text 2>&1); then
  BUCKET_EXISTS=true
  if [ -z "$BUCKET_LOCATION" ] || [ "$BUCKET_LOCATION" = "None" ]; then
    # AWS quirk: get-bucket-location returns empty/None for us-east-1
    REGION="us-east-1"
  else
    REGION="$BUCKET_LOCATION"
  fi
  echo -e "${YELLOW}Found existing state bucket — it lives in region: ${REGION}${NC}"
  echo "(using that region, regardless of this session's current AWS_REGION)"
else
  BUCKET_EXISTS=false
  REGION="${AWS_REGION:-us-east-1}"
  echo "No existing state bucket found — will create one in: $REGION"
fi
echo ""

# ----- Create S3 bucket (only if it doesn't exist) -----
if [ "$BUCKET_EXISTS" = true ]; then
  echo -e "${YELLOW}Bucket already exists — reusing it${NC}"
else
  echo "Bucket doesn't exist yet, creating in $REGION..."
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi

  aws s3api put-bucket-versioning --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled

  aws s3api put-public-access-block --bucket "$BUCKET" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  aws s3api put-bucket-encryption --bucket "$BUCKET" \
    --server-side-encryption-configuration '{
      "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
    }'

  echo -e "${GREEN}✓ Bucket created (versioned, encrypted, private)${NC}"
fi

# ----- Create DynamoDB lock table (only if it doesn't exist) -----
if aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" &>/dev/null; then
  echo -e "${YELLOW}Lock table already exists — reusing it${NC}"
else
  echo "Lock table doesn't exist yet, creating..."
  aws dynamodb create-table \
    --table-name "$TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region "$REGION" > /dev/null

  echo "Waiting for table to become active..."
  aws dynamodb wait table-exists --table-name "$TABLE" --region "$REGION"
  echo -e "${GREEN}✓ Table created${NC}"
fi

# ----- Connect Terraform to this backend -----
# main.tf now has the real bucket/key/region/table values hardcoded
# (fixed for this AWS account), so a plain `terraform init` works
# correctly with zero flags — including if you (or anyone) ever runs
# `terraform init` directly instead of this script.
echo ""
echo "Running terraform init..."
echo ""

terraform init -reconfigure

echo ""
echo "=========================================="
echo -e "${GREEN}✓ Connected to remote state${NC}"
echo "=========================================="
echo ""
echo "Next:"
echo "  terraform plan     (shows 'no changes' if the cluster already exists)"
echo "  terraform apply    (creates it, or applies any new changes)"
echo ""
