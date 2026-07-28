provider "aws" {
  region = var.aws_region
}

# Since this is a PRIVATE-only API endpoint cluster, `terraform apply` must be
# run from something with network access to the VPC (a bastion / VPN / Cloud9
# in the VPC, or an SSM-connected instance, or CodeBuild running inside the VPC).
# See README.md "Prerequisites" for details.

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
