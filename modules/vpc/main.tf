###########
# Defaults
##########

terraform {
  required_version = ">= 0.13"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.10"
    }
  }
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
  count = var.create_vpc == true ? 1 : 0

  cidr_block           = var.cidr
  instance_tenancy     = var.instance_tenancy
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
  )
}

resource "aws_vpc_endpoint" "s3" {
  count = var.create_vpc == true ? 1 : 0

  vpc_id       = aws_vpc.main[count.index].id
  service_name = "com.amazonaws.${var.region}.s3"

  tags = merge(
    var.tags,
  )
}

resource "aws_vpc_endpoint_route_table_association" "private_A" {
  count = var.create_vpc == true && length(var.private_subnets_A) > 0 ? 1 : 0

  route_table_id  = aws_route_table.private_A[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
}

resource "aws_vpc_endpoint_route_table_association" "private_B" {
  count = var.create_vpc == true && length(var.private_subnets_B) > 0 ? 1 : 0

  route_table_id  = aws_route_table.private_B[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "gw" {
  count  = var.create_vpc == true && length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.main[count.index].id

  tags = {
    Name = "${var.name}_iGW"
  }

}

################
# Publiс routes
################
resource "aws_route_table" "public" {
  count  = var.create_vpc == true && length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.main[count.index].id

  tags = {
    Name = "${var.name}-public_routes"
  }

}

resource "aws_route" "public_internet_gateway" {
  count                  = var.create_vpc == true && length(var.public_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw[count.index].id

  timeouts {
    create = "5m"
  }
}

#################
# Private routes A
# There are as many routing tables as the number of NAT gateways
#################
resource "aws_route_table" "private_A" {
  count  = var.create_vpc == true && length(var.private_subnets_A) > 0 ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "${var.name}_private_routes_A"
  }
}

#################
# Private routes B
# There are as many routing tables as the number of NAT gateways
#################
resource "aws_route_table" "private_B" {
  count  = var.create_vpc == true && length(var.private_subnets_B) > 0 ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "${var.name}_private_routes_B"
  }
}

################
# Public subnet
################
resource "aws_subnet" "public" {
  count                   = var.create_vpc == true && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = length(regexall("^[a-z]{2}-", element(data.aws_availability_zones.available.names, count.index))) > 0 ? element(data.aws_availability_zones.available.names, count.index) : null
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    var.public_subnet_tags,
  )

}

#################
# Private subnet A
#################
resource "aws_subnet" "private_A" {
  count             = var.create_vpc == true && length(var.private_subnets_A) > 0 ? length(var.private_subnets_A) : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = var.private_subnets_A[count.index]
  availability_zone = length(regexall("^[a-z]{2}-", element(data.aws_availability_zones.available.names, count.index))) > 0 ? element(data.aws_availability_zones.available.names, count.index) : null

  tags = merge(
    var.tags,
    var.private_subnet_tags,
  )
}

#################
# Private subnet B
#################
resource "aws_subnet" "private_B" {
  count      = var.create_vpc == true && length(var.private_subnets_B) > 0 ? length(var.private_subnets_B) : 0
  vpc_id     = aws_vpc.main[0].id
  cidr_block = var.private_subnets_B[count.index]
  #availability_zone = data.aws_availability_zones.available.names[length(data.aws_availability_zones.available.names)]
  availability_zone = length(regexall("^[a-z]{2}-", element(data.aws_availability_zones.available.names, count.index))) > 0 ? element(data.aws_availability_zones.available.names, count.index) : null

  tags = merge(
    var.tags,
    var.private_subnet_tags,
  )
}


########################
# Shared Default Network ACLs
########################
resource "aws_network_acl" "public" {
  count      = var.create_vpc == true && length(var.public_subnets) > 0 ? 1 : 0
  vpc_id     = aws_vpc.main[count.index].id
  subnet_ids = concat(aws_subnet.private_A.*.id, aws_subnet.public.*.id)

  tags = {
    Name = "${var.name}_shared_default_nework_acl"
  }
}

resource "aws_network_acl_rule" "public_inbound" {
  count          = var.create_vpc == true && length(var.public_subnets) > 0 ? 1 : 0
  network_acl_id = aws_network_acl.public[0].id

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
  count          = var.create_vpc == true && length(var.public_subnets) > 0 ? 1 : 0
  network_acl_id = aws_network_acl.public[0].id

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
  count      = var.create_vpc == true && length(var.private_subnets_B) > 0 ? 1 : 0
  vpc_id     = aws_vpc.main[count.index].id
  subnet_ids = aws_subnet.private_B.*.id

  tags = {
    Name = "${var.name}_dedicated_custom_nework_acl"
  }
}

resource "aws_network_acl_rule" "custom_inbound" {
  count          = var.create_vpc == true && length(var.private_subnets_B) > 0 ? 1 : 0
  network_acl_id = aws_network_acl.custom[0].id

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
  count          = var.create_vpc == true && length(var.private_subnets_B) > 0 ? 1 : 0
  network_acl_id = aws_network_acl.custom[0].id

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
  count = var.create_vpc == true && length(var.private_subnets_A) > 0 ? 1 : 0
  vpc   = true

  tags = {
    Name = "${var.name}_EIP_nat"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  #count         = length(data.aws_availability_zones.available.names)
  count         = var.create_vpc == true && length(var.private_subnets_A) > 0 ? 1 : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.name}_EIP_nat_gateway"
  }
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route" "private_A_nat_gateway" {
  count                  = var.create_vpc == true && length(var.private_subnets_A) > 0 ? 1 : 0
  route_table_id         = aws_route_table.private_A[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "private_B_nat_gateway" {
  count                  = var.create_vpc == true && length(var.private_subnets_B) > 0 ? 1 : 0
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
  count          = var.create_vpc == true && length(var.private_subnets_A) > 0 ? length(var.private_subnets_A) : 0
  subnet_id      = aws_subnet.private_A[count.index].id
  route_table_id = aws_route_table.private_A[0].id
}

resource "aws_route_table_association" "private_B" {
  count          = var.create_vpc == true && length(var.private_subnets_B) > 0 ? length(var.private_subnets_B) : 0
  subnet_id      = aws_subnet.private_B[count.index].id
  route_table_id = aws_route_table.private_B[0].id
}

resource "aws_route_table_association" "public" {
  count          = var.create_vpc == true && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}
