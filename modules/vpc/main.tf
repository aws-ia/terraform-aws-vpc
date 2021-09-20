###########
# Defaults
##########

resource "random_string" "vpc_name_suffix" {
  count   = local.vpc_count
  length  = 6
  special = false
}

######
# VPC
######
resource "aws_vpc" "main" {
  count = local.vpc_count

  cidr_block           = var.cidr
  instance_tenancy     = var.instance_tenancy
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_vpc_endpoint" "s3" {
  count = local.vpc_count

  vpc_id       = aws_vpc.main[count.index].id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  tags = merge(var.tags)
}

resource "aws_vpc_endpoint_route_table_association" "private_a" {
  count = local.private_subnet_a_count

  route_table_id  = aws_route_table.private_a[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
}

resource "aws_vpc_endpoint_route_table_association" "private_b" {
  count = local.private_subnet_b_count

  route_table_id  = aws_route_table.private_b[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "gw" {
  count  = local.igw_count
  vpc_id = aws_vpc.main[count.index].id

  tags = {
    Name = "${local.name}_iGW"
  }

}

################
# Publiс routes
################
resource "aws_route_table" "public" {
  count  = local.public_route_table_count
  vpc_id = aws_vpc.main[count.index].id

  tags = {
    Name = "${local.name}-public_routes"
  }

}

resource "aws_route" "public_internet_gateway" {
  count                  = local.igw_count
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw[count.index].id

  timeouts {
    create = "5m"
  }
}

#################
# Private routes A
# We always create one route table per subnet, regardless of how many nat gateways are deployed
#################
resource "aws_route_table" "private_a" {
  count  = local.private_subnet_a_count
  vpc_id = aws_vpc.main[0].id
  tags = {
    Name = "${local.name}_private_route_a${count.index}"
  }
}

#################
# Private routes B
# We always create one route table per subnet, regardless of how many nat gateways are deployed
#################
resource "aws_route_table" "private_b" {
  count  = local.private_subnet_b_count
  vpc_id = aws_vpc.main[0].id
  tags = {
    Name = "${local.name}_private_routes_b${count.index}"
  }
}

################
# Public subnet
################
resource "aws_subnet" "public" {
  count                   = local.public_subnet_count
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.public_subnet_tags, { Name = "${local.name}_public_${count.index}" })

}

#################
# Private subnet A
#################
resource "aws_subnet" "private_a" {
  count             = local.private_subnet_a_count
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = local.private_subnet_a_cidrs[count.index]
  availability_zone = local.availability_zones[count.index]
  tags              = merge(var.private_subnet_tags, { Name = "${local.name}_private_a_${count.index}" })
}

#################
# Private subnet B
#################
resource "aws_subnet" "private_b" {
  count             = local.private_subnet_b_count
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = local.private_subnet_b_cidrs[count.index]
  availability_zone = local.availability_zones[count.index]
  tags              = merge(var.private_subnet_tags, { Name = "${local.name}_private_b_${count.index}" })
}


########################
# Network ACLs
########################
resource "aws_network_acl" "public" {
  count      = local.public_route_table_count
  vpc_id     = aws_vpc.main[0].id
  subnet_ids = aws_subnet.public.*.id

  tags = {
    Name = "${local.name}_public_nework_acl"
  }
}

resource "aws_network_acl_rule" "public_inbound" {
  count          = local.public_route_table_count
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
  count          = local.public_route_table_count
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

resource "aws_network_acl" "private_a" {
  count      = local.private_a_nacl_count
  vpc_id     = aws_vpc.main[0].id
  subnet_ids = aws_subnet.private_a.*.id

  tags = {
    Name = "${local.name}_private_a_nework_acl"
  }
}

resource "aws_network_acl_rule" "private_a_inbound" {
  count          = local.private_a_nacl_count
  network_acl_id = aws_network_acl.private_a[count.index].id

  egress      = false
  rule_number = var.private_a_inbound_acl_rules[0]["rule_number"]
  rule_action = var.private_a_inbound_acl_rules[0]["rule_action"]
  from_port   = lookup(var.private_a_inbound_acl_rules[0], "from_port", null)
  to_port     = lookup(var.private_a_inbound_acl_rules[0], "to_port", null)
  icmp_code   = lookup(var.private_a_inbound_acl_rules[0], "icmp_code", null)
  icmp_type   = lookup(var.private_a_inbound_acl_rules[0], "icmp_type", null)
  protocol    = var.private_a_inbound_acl_rules[0]["protocol"]
  cidr_block  = lookup(var.private_a_inbound_acl_rules[0], "cidr_block", null)
}

resource "aws_network_acl_rule" "private_a_outbound" {
  count          = local.private_a_nacl_count
  network_acl_id = aws_network_acl.private_a[count.index].id

  egress      = true
  rule_number = var.private_a_outbound_acl_rules[0]["rule_number"]
  rule_action = var.private_a_outbound_acl_rules[0]["rule_action"]
  from_port   = lookup(var.private_a_outbound_acl_rules[0], "from_port", null)
  to_port     = lookup(var.private_a_outbound_acl_rules[0], "to_port", null)
  icmp_code   = lookup(var.private_a_outbound_acl_rules[0], "icmp_code", null)
  icmp_type   = lookup(var.private_a_outbound_acl_rules[0], "icmp_type", null)
  protocol    = var.private_a_outbound_acl_rules[0]["protocol"]
  cidr_block  = lookup(var.private_a_outbound_acl_rules[0], "cidr_block", null)
}

resource "aws_network_acl" "private_b" {
  count      = local.private_b_nacl_count
  vpc_id     = aws_vpc.main[0].id
  subnet_ids = aws_subnet.private_b.*.id

  tags = {
    Name = "${local.name}_private_b_nework_acl"
  }
}

resource "aws_network_acl_rule" "private_b_inbound" {
  count          = local.private_b_nacl_count
  network_acl_id = aws_network_acl.private_b[count.index].id

  egress      = false
  rule_number = var.private_b_inbound_acl_rules[0]["rule_number"]
  rule_action = var.private_b_inbound_acl_rules[0]["rule_action"]
  from_port   = lookup(var.private_b_inbound_acl_rules[0], "from_port", null)
  to_port     = lookup(var.private_b_inbound_acl_rules[0], "to_port", null)
  icmp_code   = lookup(var.private_b_inbound_acl_rules[0], "icmp_code", null)
  icmp_type   = lookup(var.private_b_inbound_acl_rules[0], "icmp_type", null)
  protocol    = var.private_b_inbound_acl_rules[0]["protocol"]
  cidr_block  = lookup(var.private_b_inbound_acl_rules[0], "cidr_block", null)
}

resource "aws_network_acl_rule" "private_b_outbound" {
  count          = local.private_b_nacl_count
  network_acl_id = aws_network_acl.private_b[count.index].id

  egress      = true
  rule_number = var.private_b_outbound_acl_rules[0]["rule_number"]
  rule_action = var.private_b_outbound_acl_rules[0]["rule_action"]
  from_port   = lookup(var.private_b_outbound_acl_rules[0], "from_port", null)
  to_port     = lookup(var.private_b_outbound_acl_rules[0], "to_port", null)
  icmp_code   = lookup(var.private_b_outbound_acl_rules[0], "icmp_code", null)
  icmp_type   = lookup(var.private_b_outbound_acl_rules[0], "icmp_type", null)
  protocol    = var.private_b_outbound_acl_rules[0]["protocol"]
  cidr_block  = lookup(var.private_b_outbound_acl_rules[0], "cidr_block", null)
}

##############
# NAT Gateway
##############

resource "aws_eip" "nat" {
  count = local.nat_gateway_count
  vpc   = true

  tags = {
    Name = "${local.name}_EIP_a_nat_${count.index}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "${local.name}_EIP_a_nat_gateway_${count.index}"
  }
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route" "private_a_nat_gateway" {
  count                  = local.nat_gateway_private_a_count
  route_table_id         = aws_route_table.private_a[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "private_b_nat_gateway" {
  count                  = local.nat_gateway_private_b_count
  route_table_id         = aws_route_table.private_b[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id

  timeouts {
    create = "5m"
  }
}

##########################
# Route table association
##########################
resource "aws_route_table_association" "private_a" {
  count          = local.private_subnet_a_count
  subnet_id      = aws_subnet.private_a[count.index].id
  route_table_id = aws_route_table.private_a[count.index].id
}

resource "aws_route_table_association" "private_b" {
  count          = local.private_subnet_b_count
  subnet_id      = aws_subnet.private_b[count.index].id
  route_table_id = aws_route_table.private_b[count.index].id
}

resource "aws_route_table_association" "public" {
  count          = local.public_subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}
