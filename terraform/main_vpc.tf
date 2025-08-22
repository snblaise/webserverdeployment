# ========================================
# VPC and Networking Configuration
# ========================================

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Main VPC
resource "aws_vpc" "main" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-igw"
  })
}

# ========================================
# Public Subnets
# ========================================

# Public subnets for ALB and NAT gateways
resource "aws_subnet" "public" {
  count = var.create_vpc ? var.az_count : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-public-subnet-${count.index + 1}"
    Type = "Public"
  })
}

# ========================================
# Private Subnets
# ========================================

# Private subnets for EC2 instances
resource "aws_subnet" "private" {
  count = var.create_vpc ? var.az_count : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index + 100)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-private-subnet-${count.index + 1}"
    Type = "Private"
  })
}

# ========================================
# Route Tables
# ========================================

# Public route table
resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-public-rt"
    Type = "Public"
  })
}

# Private route tables (one per AZ for NAT gateway redundancy)
resource "aws_route_table" "private" {
  count = var.create_vpc ? var.az_count : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-private-rt-${count.index + 1}"
    Type = "Private"
  })
}

# ========================================
# Route Table Associations
# ========================================

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = var.create_vpc ? var.az_count : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count = var.create_vpc ? var.az_count : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ========================================
# NAT Gateways
# ========================================

locals {
  common_tags = merge(
    {
      Project       = var.project_name
      Environment   = var.env
      ManagedBy     = "terraform"
      Owner         = var.owner
      Application   = var.application
      CostCenter    = var.cost_center
      CreatedBy     = "terraform"
      CreatedDate   = formatdate("YYYY-MM-DD", timestamp())
      Repository    = "secure-cicd-pipeline"
      TerraformPath = path.cwd
    },
    # Environment-specific tags
    var.env == "prod" ? {
      CriticalSystem = "true"
      Backup         = "required"
      Monitoring     = "enhanced"
      Compliance     = "required"
    } : {},
    var.env == "staging" ? {
      ProductionLike = "true"
      Backup         = "required"
      Monitoring     = "enhanced"
      ApprovalGate   = "required"
    } : {},
    var.env == "test" ? {
      CostOptimized = "true"
      AutoCleanup   = "true"
      Backup        = "optional"
      Monitoring    = "basic"
    } : {},
    var.env == "preview" ? {
      Temporary     = "true"
      AutoCleanup   = "true"
      Backup        = "none"
      Monitoring    = "basic"
      CostOptimized = "true"
    } : {},
    var.additional_tags
  )
}

# Elastic IPs for NAT gateways
resource "aws_eip" "nat" {
  count = var.create_vpc ? var.az_count : 0

  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-nat-eip-${count.index + 1}"
  })
}

# NAT gateways in public subnets
resource "aws_nat_gateway" "main" {
  count = var.create_vpc ? var.az_count : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-nat-gw-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# ========================================
# VPC Endpoints for SSM (Private Subnet Access)
# ========================================

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  count = var.create_vpc ? 1 : 0

  name_prefix = "${var.project_name}-${var.env}-vpc-endpoints-"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-vpc-endpoints-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Endpoint for SSM
resource "aws_vpc_endpoint" "ssm" {
  count = var.create_vpc ? 1 : 0

  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:SendCommand",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation",
          "ssm:GetDeployablePatchSnapshotForInstance",
          "ssm:GetDefaultPatchBaseline",
          "ssm:GetPatchBaseline",
          "ssm:DescribePatchBaselines",
          "ssm:DescribePatchGroups",
          "ssm:DescribeInstancePatchStates",
          "ssm:DescribeInstancePatches",
          "ssm:DescribePatchProperties"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-ssm-endpoint"
  })
}

# VPC Endpoint for EC2 Messages
resource "aws_vpc_endpoint" "ec2messages" {
  count = var.create_vpc ? 1 : 0

  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-ec2messages-endpoint"
  })
}

# VPC Endpoint for SSM Messages
resource "aws_vpc_endpoint" "ssmmessages" {
  count = var.create_vpc ? 1 : 0

  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-ssmmessages-endpoint"
  })
}