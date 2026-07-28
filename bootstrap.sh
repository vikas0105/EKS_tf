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

echo "=========================================="
echo "  Connecting to Terraform Remote State"
echo "=========================================="
echo ""

# ----- Config (deterministic — same every run) -----
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="${AWS_REGION:-us-east-1}"
BUCKET="eks-tf-state-${ACCOUNT_ID}"
TABLE="eks-tf-locks"
KEY="eks/terraform.tfstate"

echo "Account:  $ACCOUNT_ID"
echo "Region:   $REGION"
echo "Bucket:   $BUCKET"
echo "Table:    $TABLE"
echo ""

# ----- Create S3 bucket (only if it doesn't exist) -----
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo -e "${YELLOW}Bucket already exists — reusing it${NC}"
else
  echo "Bucket doesn't exist yet, creating..."
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
# main.tf has an intentionally empty `backend "s3" {}` block.
# We supply the real values here, every run, via -backend-config.
# This is Terraform's built-in "partial configuration" feature —
# nothing in the repo ever needs to change for this to work.
echo ""
echo "Running terraform init..."
echo ""

terraform init -reconfigure \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=${KEY}" \
  -backend-config="region=${REGION}" \
  -backend-config="dynamodb_table=${TABLE}" \
  -backend-config="encrypt=true"

echo ""
echo "=========================================="
echo -e "${GREEN}✓ Connected to remote state${NC}"
echo "=========================================="
echo ""
echo "Next:"
echo "  terraform plan     (shows 'no changes' if the cluster already exists)"
echo "  terraform apply    (creates it, or applies any new changes)"
echo ""
