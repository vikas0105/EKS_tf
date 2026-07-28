#!/bin/bash

# ============================================
# EKS Cluster Validation Script
# ============================================
# Performs comprehensive validation of EKS cluster deployment

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# ============================================
# Functions
# ============================================

check() {
  local test_name=$1
  local test_command=$2

  echo -n "Checking: $test_name... "

  if eval "$test_command" &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((CHECKS_PASSED++))
  else
    echo -e "${RED}✗ FAIL${NC}"
    ((CHECKS_FAILED++))
  fi
}

warn() {
  local test_name=$1
  local test_command=$2

  echo -n "Checking: $test_name... "

  if eval "$test_command" &> /dev/null; then
    echo -e "${YELLOW}⚠ WARNING${NC}"
    ((CHECKS_WARNING++))
  else
    echo -e "${GREEN}✓ OK${NC}"
    ((CHECKS_PASSED++))
  fi
}

print_header() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
}

print_summary() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE}Validation Summary${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "Passed:  ${GREEN}$CHECKS_PASSED${NC}"
  if [ $CHECKS_WARNING -gt 0 ]; then
    echo -e "Warnings: ${YELLOW}$CHECKS_WARNING${NC}"
  fi
  if [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "Failed:  ${RED}$CHECKS_FAILED${NC}"
  fi
  echo ""

  if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
  else
    echo -e "${RED}✗ Some checks failed. See details above.${NC}"
    exit 1
  fi
}

# ============================================
# Validation Checks
# ============================================

main() {
  print_header "EKS Cluster Validation"

  # Get cluster name from terraform
  if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform" ]; then
    echo -e "${RED}Error: Terraform state not found. Have you run 'terraform apply'?${NC}"
    exit 1
  fi

  CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
  AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

  if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${RED}Error: Could not retrieve cluster name. Run 'terraform apply' first.${NC}"
    exit 1
  fi

  echo "Cluster Name: $CLUSTER_NAME"
  echo "Region: $AWS_REGION"
  echo ""

  # ============================================
  # Terraform Checks
  # ============================================
  print_header "Terraform State"

  check "Terraform state exists" "[ -f terraform.tfstate ]"
  check "Terraform state contains vpc module" "grep -q 'vpc' terraform.tfstate"
  check "Terraform state contains eks module" "grep -q 'eks' terraform.tfstate"
  check "Terraform state contains node_group module" "grep -q 'node_group' terraform.tfstate"
  check "Terraform state contains alb_controller module" "grep -q 'alb_controller' terraform.tfstate"

  # ============================================
  # AWS Checks
  # ============================================
  print_header "AWS Resources"

  check "AWS CLI configured" "aws sts get-caller-identity > /dev/null"
  check "EKS cluster exists and is ACTIVE" "[ \"\$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query cluster.status --output text 2>/dev/null || echo NOTFOUND)\" = \"ACTIVE\" ]"
  check "EKS cluster version" "[ -n \"\$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query cluster.version --output text 2>/dev/null)\" ]"
  check "Node group exists" "aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --query nodegroups[0] --output text | grep -q '^[a-zA-Z]'"
  check "Node group status is ACTIVE" "[ \"\$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name \$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --query nodegroups[0] --output text) --region $AWS_REGION --query nodegroup.status --output text 2>/dev/null || echo NOTFOUND)\" = \"ACTIVE\" ]"

  # ============================================
  # Kubernetes Checks
  # ============================================
  print_header "Kubernetes Cluster"

  check "kubectl is installed" "command -v kubectl > /dev/null"
  check "kubeconfig configured" "kubectl cluster-info > /dev/null 2>&1"
  check "Can connect to cluster" "kubectl get nodes > /dev/null 2>&1"
  check "At least one node is Ready" "kubectl get nodes --no-headers 2>/dev/null | grep -q 'Ready'"
  check "Nodes use AL2023" "kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.osImage}' | grep -q 'Amazon Linux 2'"

  # ============================================
  # ALB Controller Checks
  # ============================================
  print_header "ALB Controller"

  check "ALB controller namespace exists" "kubectl get namespace kube-system > /dev/null 2>&1"
  check "ALB controller pods exist" "kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller 2>/dev/null | grep -q 'aws-load-balancer-controller'"
  check "ALB controller pods are Running" "[ \"\$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo '')\" = \"Running\" ]"
  check "ALB controller service account exists" "kubectl get sa -n kube-system aws-load-balancer-controller > /dev/null 2>&1"

  # ============================================
  # IRSA Checks
  # ============================================
  print_header "IRSA Configuration"

  check "OIDC provider configured" "kubectl describe sa aws-load-balancer-controller -n kube-system 2>/dev/null | grep -q 'eks.amazonaws.com/role-arn'"
  check "ALB controller IAM role exists" "aws iam get-role --role-name $CLUSTER_NAME-alb-controller-role --region $AWS_REGION > /dev/null 2>&1"

  # ============================================
  # VPC Checks
  # ============================================
  print_header "VPC Configuration"

  VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
  if [ -n "$VPC_ID" ]; then
    check "VPC exists" "aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $AWS_REGION > /dev/null 2>&1"
    check "Subnets exist" "aws ec2 describe-subnets --region $AWS_REGION --filters \"Name=vpc-id,Values=$VPC_ID\" --query 'Subnets[*].SubnetId' --output text | grep -q subnet"
    check "Security groups exist" "aws ec2 describe-security-groups --region $AWS_REGION --filters \"Name=vpc-id,Values=$VPC_ID\" --query 'SecurityGroups[*].GroupId' --output text | grep -q sg"
  fi

  # ============================================
  # Network Checks
  # ============================================
  print_header "Network Connectivity"

  check "Private cluster endpoint is enabled" "aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query cluster.resourcesVpcConfig.endpointPrivateAccess --output text | grep -q 'true'"
  warn "Public endpoint is disabled (expected for private cluster)" "aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query cluster.resourcesVpcConfig.endpointPublicAccess --output text | grep -q 'false'"

  # ============================================
  # Logging Checks
  # ============================================
  print_header "Logging"

  check "Cluster logging enabled" "aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query cluster.logging.clusterLogging --output text | grep -q 'Enabled'"

  # ============================================
  # Summary
  # ============================================
  print_summary
}

# Run main function
main "$@"
