# modules/network/main.tf - Placeholder 

provider "aws" {}

locals {
  # Ensure consistent tagging across resources
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment_name
    }
  )
  num_azs = length(var.availability_zones)
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-vpc"
  })
}

# ------------------------------------------------------------------------------
# Internet Gateway
# ------------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-igw"
  })
}

# ------------------------------------------------------------------------------
# Subnets
# ------------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = local.num_azs
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-public-subnet-${var.availability_zones[count.index]}"
    Tier = "Public"
  })
}

resource "aws_subnet" "private" {
  count             = local.num_azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-private-subnet-${var.availability_zones[count.index]}"
    Tier = "Private"
  })
}

resource "aws_subnet" "db" {
  count             = local.num_azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-db-subnet-${var.availability_zones[count.index]}"
    Tier = "Database"
  })
}

# ------------------------------------------------------------------------------
# NAT Gateways & Elastic IPs
# ------------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count = local.num_azs
  # depends_on = [aws_internet_gateway.main] # Implicit dependency via aws_nat_gateway

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-nat-eip-${var.availability_zones[count.index]}"
  })
}

resource "aws_nat_gateway" "main" {
  count         = local.num_azs
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-nat-gw-${var.availability_zones[count.index]}"
  })

  # Ensure IGW is created before NAT Gateway
  depends_on = [aws_internet_gateway.main]
}

# ------------------------------------------------------------------------------
# Route Tables
# ------------------------------------------------------------------------------

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-public-rt"
    Tier = "Public"
  })
}

resource "aws_route_table_association" "public" {
  count          = local.num_azs
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (one per AZ)
resource "aws_route_table" "private" {
  count  = local.num_azs
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-private-rt-${var.availability_zones[count.index]}"
    Tier = "Private"
  })
}

resource "aws_route_table_association" "private" {
  count          = local.num_azs
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Database Route Tables (one per AZ) - Using same routing as private for now
resource "aws_route_table" "db" {
  count  = local.num_azs
  vpc_id = aws_vpc.main.id

  # Route outbound traffic through NAT Gateway in the same AZ
  # Can be made more restrictive if needed (e.g., only allow access to specific AWS services)
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-db-rt-${var.availability_zones[count.index]}"
    Tier = "Database"
  })
}

resource "aws_route_table_association" "db" {
  count          = local.num_azs
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db[count.index].id
} 