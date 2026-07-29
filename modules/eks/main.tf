# ============================================
# EKS Module - Kubernetes Cluster
# ============================================

# ============================================
# EKS Cluster
# ============================================
resource "aws_eks_cluster" "main" {
  name    = var.cluster_name
  version = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    # Private cluster - only private API endpoint
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = var.security_group_ids
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.vpc_cni_policy,
    aws_cloudwatch_log_group.cluster
  ]
}

# ============================================
# Cluster IAM Role
# ============================================
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Attach required policies to cluster role
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.cluster.name
}

# ============================================
# OIDC Provider (for IRSA)
# ============================================

# Get the OIDC provider thumbprint
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Create OIDC provider for service account IAM roles
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

# ============================================
# CloudWatch Log Group for cluster logs
# ============================================
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

  tags = var.tags
}

# ============================================
# Security Group Rules (if needed)
# ============================================
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    description = "Allow API access"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}
