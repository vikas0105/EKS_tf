.PHONY: help init validate plan apply destroy deploy test clean fmt refresh output state-list state-show logs nodes kubeconfig

# ============================================
# Variables
# ============================================
TERRAFORM := terraform
KUBECTL := kubectl
AWS := aws
CLUSTER_NAME := $(shell $(TERRAFORM) output -raw eks_cluster_name 2>/dev/null || echo "unknown")
AWS_REGION := $(shell $(TERRAFORM) output -raw aws_region 2>/dev/null || echo "us-east-1")

# ============================================
# Help
# ============================================
help:
	@echo "EKS Terraform Makefile - Available targets:"
	@echo ""
	@echo "Setup & Deployment:"
	@echo "  init              - Initialize Terraform"
	@echo "  validate          - Validate Terraform syntax"
	@echo "  fmt               - Format Terraform files"
	@echo "  plan              - Show deployment plan"
	@echo "  apply             - Apply Terraform changes"
	@echo "  deploy            - Full automated deployment (init -> plan -> apply)"
	@echo "  destroy           - Destroy all resources (WARNING!)"
	@echo ""
	@echo "Validation & Status:"
	@echo "  test              - Run validation script"
	@echo "  refresh           - Refresh Terraform state"
	@echo "  output            - Show all Terraform outputs"
	@echo "  state-list        - List all resources in state"
	@echo "  state-show RES=   - Show specific resource (e.g., make state-show RES=aws_eks_cluster.main)"
	@echo ""
	@echo "Kubernetes Operations:"
	@echo "  kubeconfig        - Configure kubectl for the cluster"
	@echo "  nodes             - List cluster nodes"
	@echo "  pods              - List all pods in the cluster"
	@echo "  logs              - Tail ALB controller logs"
	@echo ""
	@echo "Utilities:"
	@echo "  clean             - Clean Terraform cache and files"
	@echo "  vars              - Show current Terraform variables"
	@echo "  cost              - Estimate monthly cost"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy       - Deploy EKS cluster with ALB controller"
	@echo "  make test         - Run comprehensive validation"
	@echo "  make destroy      - Destroy cluster (after confirmation)"

# ============================================
# Terraform Commands
# ============================================

init:
	$(TERRAFORM) init -upgrade
	@echo "✓ Terraform initialized"

validate:
	$(TERRAFORM) validate
	@echo "✓ Terraform configuration is valid"

fmt:
	$(TERRAFORM) fmt -recursive
	@echo "✓ Terraform files formatted"

plan:
	$(TERRAFORM) plan -out=tfplan
	@echo "✓ Plan created (tfplan)"

apply:
	$(TERRAFORM) apply tfplan
	@echo "✓ Changes applied"
	@rm -f tfplan

deploy: init validate plan apply kubeconfig test
	@echo ""
	@echo "✓ Deployment complete!"
	@echo "Run 'make help' for more commands"

destroy:
	@echo "WARNING: This will destroy all EKS cluster resources!"
	@echo "Resources to be destroyed:"
	@$(TERRAFORM) plan -destroy | grep "will be destroyed" | head -5
	@echo ""
	@read -p "Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		$(TERRAFORM) destroy; \
		echo "✓ Resources destroyed"; \
	else \
		echo "Destruction cancelled"; \
	fi

# ============================================
# Validation & Status
# ============================================

test:
	@chmod +x validate.sh
	@./validate.sh

refresh:
	$(TERRAFORM) refresh
	@echo "✓ State refreshed"

output:
	$(TERRAFORM) output
	@echo ""
	@echo "To save outputs: $(TERRAFORM) output -json > outputs.json"

state-list:
	$(TERRAFORM) state list

state-show:
	$(TERRAFORM) state show $(RES)

# ============================================
# Kubernetes Commands
# ============================================

kubeconfig:
	@echo "Configuring kubectl..."
	@aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)
	@echo "✓ kubeconfig configured for: $(CLUSTER_NAME)"

nodes:
	@echo "Cluster Nodes ($(CLUSTER_NAME)):"
	@$(KUBECTL) get nodes -o wide

pods:
	@echo "All Pods:"
	@$(KUBECTL) get pods -A

logs:
	@echo "ALB Controller Logs:"
	@$(KUBECTL) logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50 -f || echo "No logs available yet"

# ============================================
# Utilities
# ============================================

clean:
	@echo "Cleaning Terraform files..."
	@rm -rf .terraform/
	@rm -f .terraform.lock.hcl
	@rm -f tfplan
	@rm -f terraform.tfstate*
	@echo "✓ Cleaned"

vars:
	@echo "Current Variables:"
	@grep -E "^\s*(.*)\s*=" terraform.tfvars | grep -v "^#"

cost:
	@echo "Estimated Monthly Cost ($(CLUSTER_NAME)):"
	@echo ""
	@echo "EKS Cluster:          ~$73.00"
	@echo "EC2 t3.medium (1x):   ~$29.00"
	@echo "NAT Gateways (2x):    ~$66.00"
	@echo "Data Transfer:        ~Variable"
	@echo "─────────────────────────────"
	@echo "Total (Approximate):  ~$168.00/month"
	@echo ""
	@echo "Note: Prices are for us-east-1 and may vary by region"
	@echo "Use AWS Calculator for accurate pricing: https://calculator.aws/"

# ============================================
# Development Commands
# ============================================

.SILENT: help vars cost
