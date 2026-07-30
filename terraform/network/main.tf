locals {
  module_name = "network"
  default_tags = {
    Workspace = terraform.workspace
    Module    = local.module_name
    Terraform = "true"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Master VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-vpc"
  })
}

# Public subnets
resource "aws_subnet" "public" {
  count                   = var.public_subnet_count
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = merge(local.default_tags, {
    Name       = "${terraform.workspace}-public-subnet-${count.index}"
    SubnetType = "public"
  })
}

# Private subnets
resource "aws_subnet" "private" {
  count                   = var.private_subnet_count
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index + 100}.0/24"
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.main.id

  tags = merge(local.default_tags, {
    Name       = "${terraform.workspace}-private-subnet-${count.index}"
    SubnetType = "private"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-igw"
  })
}

# Elastic IP address for NAT gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-nat-eip"
  })
}

# Network Address Translation (NAT) gateway to connect private subnets to the public
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-nat-gateway"
  })
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.default_tags, {
    Name       = "${terraform.workspace}-public-route-table"
    SubnetType = "public"
  })
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = var.public_subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  count          = var.private_subnet_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

data "aws_region" "current" {}

# VPC Endpoints to reduce NAT gateway traffic and costs

# S3 Gateway Endpoint (free - no hourly charge or data processing costs)
# ECR stores image layers in S3, so this alone eliminates most NAT traffic from image pulls
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-s3-endpoint"
  })
}

# Security group for interface VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${terraform.workspace}-vpc-endpoints-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-vpc-endpoints-sg"
  })
}

# ECR API Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private.*.id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecr-api-endpoint"
  })
}

# ECR Docker Endpoint (for image layer pulls)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private.*.id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecr-dkr-endpoint"
  })
}

# CloudWatch Logs Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private.*.id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-logs-endpoint"
  })
}

# CloudWatch Monitoring Endpoint
resource "aws_vpc_endpoint" "monitoring" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.monitoring"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private.*.id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-monitoring-endpoint"
  })
}

# SSM Parameter Store Endpoint
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private.*.id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ssm-endpoint"
  })
}