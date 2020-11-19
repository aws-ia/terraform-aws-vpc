###########
# Defaults
##########

terraform {
  required_version = ">= 0.13"

  backend "remote" {}
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

######
# VPC
######
resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  instance_tenancy     = var.instance_tenancy
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = {
    Terraform = "true"
    Name      = "${var.name}_vpc"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.s3"

  tags = {
    Terraform = "true"
    Name      = "${var.name}_vpc_endpoint"
  }
}

resource "aws_vpc_endpoint_route_table_association" "private_A" {
  count = length(data.aws_availability_zones.available.names)

  route_table_id  = aws_route_table.private_A[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_route_table_association" "private_B" {
  count = length(data.aws_availability_zones.available.names)

  route_table_id  = aws_route_table.private_B[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}_iGW"
  }

}

################
# Publiс routes
################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-public_routes"
  }

}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id

  timeouts {
    create = "5m"
  }
}

#################
# Private routes A
# There are as many routing tables as the number of NAT gateways
#################
resource "aws_route_table" "private_A" {
  count  = length(data.aws_availability_zones.available.names)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}_private_routes_A"
  }
}

#################
# Private routes B
# There are as many routing tables as the number of NAT gateways
#################
resource "aws_route_table" "private_B" {
  count  = length(data.aws_availability_zones.available.names)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}_private_routes_B"
  }
}

################
# Public subnet
################
resource "aws_subnet" "public" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}_public_subnets"
  }
}

#################
# Private subnet A
#################
resource "aws_subnet" "private_A" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_A[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name}_private_subnets_A"
  }
}

#################
# Private subnet B
#################
resource "aws_subnet" "private_B" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_B[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name}_private_subnets_B"
  }
}


########################
# Shared Default Network ACLs
########################
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = concat(aws_subnet.private_A.*.id, aws_subnet.public.*.id)

  tags = {
    Name = "${var.name}_shared_default_nework_acl"
  }
}

resource "aws_network_acl_rule" "public_inbound" {
  network_acl_id = aws_network_acl.public.id

  egress      = false
  rule_number = var.public_inbound_acl_rules[0]["rule_number"]
  rule_action = var.public_inbound_acl_rules[0]["rule_action"]
  from_port   = lookup(var.public_inbound_acl_rules[0], "from_port", null)
  to_port     = lookup(var.public_inbound_acl_rules[0], "to_port", null)
  icmp_code   = lookup(var.public_inbound_acl_rules[0], "icmp_code", null)
  icmp_type   = lookup(var.public_inbound_acl_rules[0], "icmp_type", null)
  protocol    = var.public_inbound_acl_rules[0]["protocol"]
  cidr_block  = lookup(var.public_inbound_acl_rules[0], "cidr_block", null)
}

resource "aws_network_acl_rule" "public_outbound" {
  network_acl_id = aws_network_acl.public.id

  egress      = true
  rule_number = var.public_outbound_acl_rules[0]["rule_number"]
  rule_action = var.public_outbound_acl_rules[0]["rule_action"]
  from_port   = lookup(var.public_outbound_acl_rules[0], "from_port", null)
  to_port     = lookup(var.public_outbound_acl_rules[0], "to_port", null)
  icmp_code   = lookup(var.public_outbound_acl_rules[0], "icmp_code", null)
  icmp_type   = lookup(var.public_outbound_acl_rules[0], "icmp_type", null)
  protocol    = var.public_outbound_acl_rules[0]["protocol"]
  cidr_block  = lookup(var.public_outbound_acl_rules[0], "cidr_block", null)
}


#######################
# Dedicated  Custom Network ACLs
#######################
resource "aws_network_acl" "custom" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private_B.*.id

  tags = {
    Name = "${var.name}_dedicated_custom_nework_acl"
  }
}

resource "aws_network_acl_rule" "custom_inbound" {
  network_acl_id = aws_network_acl.custom.id

  egress      = false
  rule_number = var.custom_inbound_acl_rules[0]["rule_number"]
  rule_action = var.custom_inbound_acl_rules[0]["rule_action"]
  from_port   = lookup(var.custom_inbound_acl_rules[0], "from_port", null)
  to_port     = lookup(var.custom_inbound_acl_rules[0], "to_port", null)
  icmp_code   = lookup(var.custom_inbound_acl_rules[0], "icmp_code", null)
  icmp_type   = lookup(var.custom_inbound_acl_rules[0], "icmp_type", null)
  protocol    = var.custom_inbound_acl_rules[0]["protocol"]
  cidr_block  = lookup(var.custom_inbound_acl_rules[0], "cidr_block", null)
}

resource "aws_network_acl_rule" "custom_outbound" {
  network_acl_id = aws_network_acl.custom.id

  egress      = true
  rule_number = var.custom_outbound_acl_rules[0]["rule_number"]
  rule_action = var.custom_outbound_acl_rules[0]["rule_action"]
  from_port   = lookup(var.custom_outbound_acl_rules[0], "from_port", null)
  to_port     = lookup(var.custom_outbound_acl_rules[0], "to_port", null)
  icmp_code   = lookup(var.custom_outbound_acl_rules[0], "icmp_code", null)
  icmp_type   = lookup(var.custom_outbound_acl_rules[0], "icmp_type", null)
  protocol    = var.custom_outbound_acl_rules[0]["protocol"]
  cidr_block  = lookup(var.custom_outbound_acl_rules[0], "cidr_block", null)
}

##############
# NAT Gateway
##############

resource "aws_eip" "nat" {
  count = length(data.aws_availability_zones.available.names)
  vpc   = true

  tags = {
    Name = "${var.name}_EIP_nat"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  count         = length(data.aws_availability_zones.available.names)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.name}_EIP_nat_gateway"
  }
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route" "private_A_nat_gateway" {
  count                  = length(data.aws_availability_zones.available.names)
  route_table_id         = aws_route_table.private_A[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "private_B_nat_gateway" {
  count                  = length(data.aws_availability_zones.available.names)
  route_table_id         = aws_route_table.private_B[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id

  timeouts {
    create = "5m"
  }
}

##########################
# Route table association
##########################
resource "aws_route_table_association" "private_A" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.private_A[count.index].id
  route_table_id = aws_route_table.private_A[count.index].id
}

resource "aws_route_table_association" "private_B" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.private_B[count.index].id
  route_table_id = aws_route_table.private_B[count.index].id
}

resource "aws_route_table_association" "public" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
