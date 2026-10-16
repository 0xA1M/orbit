# fetch every usable AZ in the region, we place resources by index of this list
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# the network container itself; DNS flags required by Service Connect + ALB name resolution
resource "aws_vpc" "infra_ecs_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-ecs-vpc"
  }
}

# one per VPC; gives public subnets a route out and the ALB a way in
resource "aws_internet_gateway" "infra_ecs_igw" {
  vpc_id = aws_vpc.infra_ecs_vpc.id

  tags = {
    Name = "${var.name_prefix}-ecs-igw"
  }
}

# one static IP per NAT, lives with the NAT in its AZ
resource "aws_eip" "infra_ecs_eip" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-ecs-eip"
  }
}

# ALB lives here, one per AZ; map_public_ip_on_launch is what makes it ALB-eligible
resource "aws_subnet" "infra_ecs_pub_subnet" {
  vpc_id = aws_vpc.infra_ecs_vpc.id
  count  = 2

  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-ecs-pub-subnet"
  }
}

# all Fargate tasks live here, private-only, egress via own-AZ NAT
resource "aws_subnet" "infra_ecs_prv_subnet" {
  vpc_id = aws_vpc.infra_ecs_vpc.id
  count  = 2

  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 8)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-ecs-prv-subnet"
  }
}

# one NAT per AZ: each private subnet egresses through the NAT of its own AZ.
# the IGW must exist first or the NAT API call races ahead and fails
resource "aws_nat_gateway" "infra_ecs_nat_gw" {
  allocation_id = aws_eip.infra_ecs_eip[count.index].id
  subnet_id     = aws_subnet.infra_ecs_pub_subnet[count.index].id
  depends_on    = [aws_internet_gateway.infra_ecs_igw]
  count         = 2

  tags = {
    Name = "${var.name_prefix}-ecs-nat"
  }
}

# single table shared by both public subnets: 0.0.0.0/0 straight to the IGW
resource "aws_route_table" "infra_ecs_pub_route_tbl" {
  vpc_id = aws_vpc.infra_ecs_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.infra_ecs_igw.id
  }

  tags = {
    Name = "${var.name_prefix}-pub-route-tbl"
  }
}

# one per AZ, each defaulted to its own-AZ NAT; no inbound route at all
resource "aws_route_table" "infra_ecs_prv_route_tbl" {
  vpc_id = aws_vpc.infra_ecs_vpc.id
  count  = 2

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.infra_ecs_nat_gw[count.index].id
  }

  tags = {
    Name = "${var.name_prefix}-prv-route-tbl"
  }
}

# pairs public subnets with the one shared public table
resource "aws_route_table_association" "infra_ecs_pub_route_tbl_ass" {
  route_table_id = aws_route_table.infra_ecs_pub_route_tbl.id
  subnet_id      = aws_subnet.infra_ecs_pub_subnet[count.index].id
  count          = 2
}

# pairs each private subnet with its own-AZ private table (same index on both sides)
resource "aws_route_table_association" "infra_ecs_prv_route_tbl_ass" {
  route_table_id = aws_route_table.infra_ecs_prv_route_tbl[count.index].id
  subnet_id      = aws_subnet.infra_ecs_prv_subnet[count.index].id
  count          = 2
}