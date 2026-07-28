# ============================================
# ALB Controller Module - Load Balancer Management
# ============================================

# ============================================
# Namespace for ALB Controller
# ============================================
resource "kubernetes_namespace" "alb_controller" {
  metadata {
    name = "kube-system"
  }
}

# ============================================
# IAM Role for ALB Controller (IRSA)
# ============================================
resource "aws_iam_role" "alb_controller" {
  name = "${var.cluster_name}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# ============================================
# IAM Policy for ALB Controller
# ============================================
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "IAM policy for ALB Ingress Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elbv2:CreateLoadBalancer",
          "elbv2:CreateTargetGroup",
          "elbv2:CreateListener",
          "elbv2:DeleteLoadBalancer",
          "elbv2:DeleteTargetGroup",
          "elbv2:DeleteListener",
          "elbv2:DescribeLoadBalancers",
          "elbv2:DescribeTargetGroups",
          "elbv2:DescribeListeners",
          "elbv2:DescribeLoadBalancerAttributes",
          "elbv2:DescribeTargetGroupAttributes",
          "elbv2:ModifyLoadBalancerAttributes",
          "elbv2:ModifyTargetGroupAttributes",
          "elbv2:RegisterTargets",
          "elbv2:DeregisterTargets",
          "elbv2:DescribeTargetHealth",
          "elbv2:ModifyListener"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoarseGrainedInstanceMetadata"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "acm:ListCertificates",
          "acm:DescribeCertificate"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "waf:GetWebACL"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.alb_controller.name
}

# ============================================
# Service Account for ALB Controller
# ============================================
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }

  depends_on = [kubernetes_namespace.alb_controller]
}

# ============================================
# Helm Release for ALB Controller
# ============================================
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.alb_controller_chart_version

  values = [
    jsonencode({
      replicaCount = var.alb_controller_replicas
      
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.alb_controller.metadata[0].name
      }

      clusterName = var.cluster_name

      # Enable logging
      logLevel = "info"

      # Resource requests and limits
      resources = {
        limits = {
          cpu    = "200m"
          memory = "500Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
      }

      # Pod anti-affinity for high availability
      podAntiAffinity = "preferred"

      # Enable webhook
      enableShield       = false
      enableWaf          = false
      enableWafv2        = false

      env = {
        AWS_REGION = data.aws_region.current.name
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.alb_controller
  ]
}

# ============================================
# Data Sources
# ============================================
data "aws_region" "current" {}
