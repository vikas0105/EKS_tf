# Terraform EKS Architecture

This project provisions a **private Amazon EKS cluster** on AWS using Terraform.

```text
Terraform
│
├── AWS Provider
│
├── VPC
│   ├── Public Subnets
│   ├── Private Subnets
│   ├── Internet Gateway
│   ├── NAT Gateway
│   └── Route Tables
│
├── IAM
│   ├── EKS Cluster Role
│   └── Node Group Role
│
├── Amazon EKS
│   ├── Private Control Plane
│   ├── Security Groups
│   └── OIDC Provider (IRSA)
│
└── Managed Node Group
    ├── Auto Scaling Group
    ├── Launch Template
    └── EC2 Worker Node (AL2023, t3.medium)
```

## Deployment Flow

```text
Terraform
      │
terraform init
terraform plan
terraform apply
      │
      ▼
AWS Provider
      │
      ▼
VPC → IAM → EKS Cluster → Managed Node Group
      │
      ▼
EC2 Worker Node joins the EKS Cluster
      │
      ▼
Kubernetes Components (CoreDNS, kube-proxy, VPC CNI)
```

## Components

* **Terraform** – Infrastructure as Code (IaC) provisioning.
* **VPC** – Networking for the EKS cluster.
* **IAM Roles** – Permissions for the EKS control plane and worker nodes.
* **EKS Cluster** – Managed Kubernetes control plane with a private API endpoint.
* **Managed Node Group** – Amazon Linux 2023 (`t3.medium`) worker node managed by AWS.
* **OIDC Provider** – Enables IAM Roles for Service Accounts (IRSA).
* **Kubernetes System Components** – CoreDNS, kube-proxy, and Amazon VPC CNI installed by EKS.



    
