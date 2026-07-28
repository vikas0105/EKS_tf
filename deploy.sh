#!/bin/bash
set -e

# ============================================
# EKS Cluster Deployment Script
# ============================================
# This script automates the deployment of EKS cluster with ALB controller

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Functions
# ============================================

print_header() {
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

check_prerequisites() {
  print_header "Checking Prerequisites"

  # Check Terraform
  if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
  fi
  TERRAFORM_VERSION=$(terraform -v | head -n 1)
  print_success "Terraform: $TERRAFORM_VERSION"

  # Check AWS CLI
  if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
  fi
  AWS_VERSION=$(aws --version)
  print_success "AWS CLI: $AWS_VERSION"

  # Check AWS credentials
  if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured or invalid"
    exit 1
  fi
  AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
  AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
  print_success "AWS Account: $AWS_ACCOUNT"
  print_success "AWS User: $AWS_USER"

  # Check kubectl
  if ! command -v kubectl &> /dev/null; then
    print_warning "kubectl is not installed (will be needed after deployment)"
  else
    print_success "kubectl: $(kubectl version --client --short 2>/dev/null || echo 'installed')"
  fi

  # Check Helm
  if ! command -v helm &> /dev/null; then
    print_warning "Helm is not installed (will be needed for ALB controller)"
  else
    print_success "Helm: $(helm version --short 2>/dev/null || echo 'installed')"
  fi
}

validate_configuration() {
  print_header "Validating Configuration"

  # Check if terraform.tfvars exists
  if [ ! -f "terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found"
    print_warning "Creating from terraform.tfvars.example..."
    if [ -f "terraform.tfvars.example" ]; then
      cp terraform.tfvars.example terraform.tfvars
      print_success "Created terraform.tfvars"
    else
      print_error "terraform.tfvars.example not found"
      exit 1
    fi
  fi

  # Validate Terraform syntax
  if terraform validate > /dev/null 2>&1; then
    print_success "Terraform configuration is valid"
  else
    print_error "Terraform configuration is invalid"
    terraform validate
    exit 1
  fi
}

initialize_terraform() {
  print_header "Initializing Terraform"

  if terraform init -upgrade; then
    print_success "Terraform initialized"
  else
    print_error "Terraform initialization failed"
    exit 1
  fi
}

plan_deployment() {
  print_header "Planning Deployment"

  if terraform plan -out=tfplan; then
    print_success "Terraform plan created (tfplan)"
  else
    print_error "Terraform plan failed"
    exit 1
  fi

  # Ask for confirmation
  echo ""
  read -p "Do you want to proceed with the deployment? (yes/no): " -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Deployment cancelled"
    exit 1
  fi
}

apply_deployment() {
  print_header "Applying Deployment"
  echo "This may take 15-25 minutes..."
  echo ""

  if terraform apply tfplan; then
    print_success "Terraform apply completed successfully"
    rm -f tfplan
  else
    print_error "Terraform apply failed"
    exit 1
  fi
}

configure_kubectl() {
  print_header "Configuring kubectl"

  CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null)
  AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

  if [ -z "$CLUSTER_NAME" ]; then
    print_error "Could not retrieve cluster name from outputs"
    return 1
  fi

  echo "Configuring kubectl for cluster: $CLUSTER_NAME in region: $AWS_REGION"
  
  if aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"; then
    print_success "kubectl configured"

    # Verify connectivity
    if kubectl cluster-info &> /dev/null; then
      print_success "kubectl can connect to cluster"
    else
      print_warning "kubectl may not be able to connect yet (cluster may still be initializing)"
    fi
  else
    print_error "Failed to configure kubectl"
    return 1
  fi
}

save_outputs() {
  print_header "Saving Outputs"

  if terraform output -json > outputs.json; then
    print_success "Outputs saved to outputs.json"
    
    # Print key outputs
    echo ""
    echo "Key Outputs:"
    echo "  Cluster Name: $(terraform output -raw eks_cluster_name)"
    echo "  Cluster Endpoint: $(terraform output -raw eks_cluster_endpoint)"
    echo "  Region: $(terraform output -raw aws_region)"
    echo "  VPC ID: $(terraform output -raw vpc_id)"
  fi
}

print_summary() {
  print_header "Deployment Summary"

  echo "✓ EKS cluster deployed successfully!"
  echo ""
  echo "Next steps:"
  echo "1. Wait for node group to be ready (check AWS console)"
  echo "2. Verify nodes are ready: kubectl get nodes"
  echo "3. Check ALB controller: kubectl get pods -n kube-system | grep alb"
  echo "4. Run validation: ./validate.sh"
  echo ""
  echo "Documentation:"
  echo "  - Full guide: see DEPLOYMENT_GUIDE.md"
  echo "  - Troubleshooting: see README.md"
  echo ""
}

# ============================================
# Main Execution
# ============================================

main() {
  print_header "EKS Cluster Deployment"
  echo "Starting deployment process..."
  echo ""

  check_prerequisites
  validate_configuration
  initialize_terraform
  plan_deployment
  apply_deployment
  configure_kubectl
  save_outputs
  print_summary
}

# Run main function
main
