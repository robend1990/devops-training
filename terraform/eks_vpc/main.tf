terraform {
  experiments = [variable_validation]
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = merge(var.tags, {"Name" = "${var.eks_cluster_name}-VPC"})
}

resource "aws_security_group" "cluster_to_nodes" {
  name = "${var.eks_cluster_name}-vpc-ControlPlaneSecurityGroup"
  description = "Cluster communication with worker nodes"
  vpc_id = aws_vpc.this.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_subnet" "public" {
  count = length(var.public_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = merge(var.tags, {"Name" = "${var.eks_cluster_name} - Public Subnet ${count.index}", "kubernetes.io/role/elb" = 1, "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"})
}

resource "aws_subnet" "private" {
  count = length(var.private_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = merge(var.tags, {"Name" = "${var.eks_cluster_name} - Private Subnet ${count.index}", "kubernetes.io/role/internal-elb" = 1, "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"})
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = var.tags
}

resource "aws_eip" "nat" {
  count = length(var.public_cidrs)
  vpc = true
  tags = var.tags
}

resource "aws_nat_gateway" "this" {
  count = length(var.public_cidrs)
  allocation_id = aws_eip.nat.*.id[count.index]
  subnet_id = aws_subnet.public.*.id[count.index]
  tags = merge(var.tags, {"Name" = "${var.eks_cluster_name}-vpc-NatGatewayAZ${count.index}"})
  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, {"Name" = "Public Subnets"})
}

resource "aws_route_table_association" "public" {
  count = length(var.public_cidrs)
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.public.*.id[count.index]
}

resource "aws_route_table" "private" {
  count = length(var.private_cidrs)
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {"Name" = "Private Subnet AZ ${count.index}"})
}

resource "aws_route" "private" {
  count = length(aws_route_table.private)
  route_table_id = aws_route_table.private.*.id[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.this.*.id[count.index]
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  route_table_id = aws_route_table.private.*.id[count.index]
  subnet_id = aws_subnet.private.*.id[count.index]
}

