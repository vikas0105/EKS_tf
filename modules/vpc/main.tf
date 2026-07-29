# ============================================
# VPC Module - Network Infrastructure
# ============================================

# Cap the number of AZs used to 2, regardless of how many the region
# actually has available. This keeps the architecture and cost
# predictable (2 public + 2 private subnets, 2 NAT gateways) instead of
# scaling to however many AZs a given region happens to offer — some
# regions (e.g. ap-south-1) have more than 4, which previously caused
# private subnet CIDRs to collide with public ones (the offset math
# assumed a max of 4 AZs) and would have silently created far more NAT
# gateways than intended.
locals {
  az_count = min(2, length(data.aws_availability_zones.available.names))
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
}

# ============================================
# Public Subnets (for NAT gateways and bastion)
# ============================================
resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name                                            = "${var.project_name}-public-${count.index + 1}"
      "kubernetes.io/role/elb"                        = "1"
      "kubernetes.io/cluster/${var.project_name}"     = "shared"
    }
  )
}

# ============================================
# Private Subnets (for EKS nodes)
# ============================================
resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + local.az_count)
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    {
      Name                                            = "${var.project_name}-private-${count.index + 1}"
      "kubernetes.io/role/internal-elb"               = "1"
      "kubernetes.io/cluster/${var.project_name}"     = "shared"
    }
  )
}

# ============================================
# Elastic IPs for NAT Gateways
# ============================================
resource "aws_eip" "nat" {
  count  = local.az_count
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-eip-nat-${count.index + 1}"
    }
  )
}

# ============================================
# NAT Gateways (for private subnet internet access)
# ============================================
resource "aws_nat_gateway" "main" {
  count         = local.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nat-${count.index + 1}"
    }
  )
}

# ============================================
# Public Route Table
# ============================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-rt-public"
    }
  )
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================
# Private Route Tables (one per AZ for NAT)
# ============================================
resource "aws_route_table" "private" {
  count  = local.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-rt-private-${count.index + 1}"
    }
  )
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ============================================
# Security Groups
# ============================================

# Default security group for the VPC
resource "aws_security_group" "default" {
  name        = "${var.project_name}-default-sg"
  description = "Default security group for ${var.project_name}"
  vpc_id      = aws_vpc.main.id

  # Allow all inbound from VPC
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-default-sg"
    }
  )
}

# ============================================
# Data Sources
# ============================================

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}
