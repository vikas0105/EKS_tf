                           Terraform
                              │
               terraform init / plan / apply
                              │
                              ▼
                    AWS Provider (ap-south-1)
                              │
         ┌────────────────────┴────────────────────┐
         │                                         │
         ▼                                         ▼
      IAM Roles                              VPC Module
(EKS & Node Group Roles)                         │
                                                 │
                     ┌───────────────────────────┼──────────────────────────┐
                     │                           │                          │
                     ▼                           ▼                          ▼
              Public Subnets              Private Subnets             NAT Gateway
                     │                           │
                     └───────────────┬───────────┘
                                     │
                                     ▼
                               EKS Cluster
                          (Private API Endpoint)
                                     │
                      Control Plane (Managed by AWS)
                                     │
                          Security Groups + ENIs
                                     │
                                     ▼
                        Managed Node Group
                      (AL2023, t3.medium x 1)
                                     │
                                     ▼
                            EC2 Worker Node
                                     │
                                     ▼
                              Kubernetes
                                     │
                   ┌─────────────────┼──────────────────┐
                   │                 │                  │
                   ▼                 ▼                  ▼
              kube-system       CoreDNS          kube-proxy


Terraform
│
├── VPC
│   ├── CIDR
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
├── EKS
│   ├── Control Plane
│   ├── Security Groups
│   └── OIDC Provider (if IRSA enabled)
│
└── Managed Node Group
    ├── Auto Scaling Group
    ├── Launch Template
    └── EC2 Instance(s)
