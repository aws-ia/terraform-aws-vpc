
# ---------- SUBNET CALCULATOR (IPv4 AND IPv6) ----------

module "calculate_subnets" {
  source = "./modules/calculate_subnets"

  cidr = local.cidr_block
  azs  = local.azs

  subnets = var.subnets
}

module "calculate_subnets_ipv6" {
  source = "./modules/calculate_subnets_ipv6"

  cidr_ipv6 = local.vpc_ipv6_cidr_block
  azs       = local.azs

  subnets = var.subnets
}

# ---------- VPC RESOURCE ----------
# flow logs optionally enabled by standalone resource
#tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
resource "aws_vpc" "main" {
  count = local.create_vpc ? 1 : 0

  cidr_block                       = var.cidr_block
  ipv4_ipam_pool_id                = var.vpc_ipv4_ipam_pool_id
  ipv4_netmask_length              = var.vpc_ipv4_netmask_length
  assign_generated_ipv6_cidr_block = var.vpc_assign_generated_ipv6_cidr_block
  ipv6_cidr_block                  = var.vpc_ipv6_cidr_block
  ipv6_ipam_pool_id                = var.vpc_ipv6_ipam_pool_id
  ipv6_netmask_length              = var.vpc_ipv6_netmask_length

  enable_dns_hostnames = var.vpc_enable_dns_hostnames
  enable_dns_support   = var.vpc_enable_dns_support
  instance_tenancy     = var.vpc_instance_tenancy

  tags = merge(
    { "Name" = var.name },
    module.tags.tags_aws
  )
}

# ---------- SECONDARY IPv4 CIDR BLOCK (if configured) ----------
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  count = (var.vpc_secondary_cidr && !local.create_vpc) ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = local.cidr_block
  ipv4_ipam_pool_id = var.vpc_ipv4_ipam_pool_id
}

# ---------- PUBLIC SUBNET CONFIGURATION ----------
# Public Subnets
resource "aws_subnet" "public" {
  for_each = contains(local.subnet_keys, "public") ? toset(local.azs) : toset([])

  availability_zone                              = each.key
  vpc_id                                         = local.vpc.id
  cidr_block                                     = can(local.calculated_subnets["public"][each.key]) ? local.calculated_subnets["public"][each.key] : null
  ipv6_cidr_block                                = can(local.calculated_subnets_ipv6["public"][each.key]) ? local.calculated_subnets_ipv6["public"][each.key] : null
  ipv6_native                                    = contains(local.subnets_with_ipv6_native, "public") ? true : false
  map_public_ip_on_launch                        = local.public_ipv6only ? null : true
  assign_ipv6_address_on_creation                = local.public_ipv6only || local.public_dualstack ? true : null
  enable_resource_name_dns_aaaa_record_on_launch = local.public_ipv6only || local.public_dualstack ? true : false

  tags = merge(
    { Name = "${local.subnet_names["public"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["public"].tags_aws, {})
  )
}

# Public subnet Route Table and association
resource "aws_route_table" "public" {
  for_each = contains(local.subnet_keys, "public") ? toset(local.azs) : toset([])

  vpc_id = local.vpc.id

  tags = merge(
    { Name = "${local.subnet_names["public"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["public"].tags_aws, {})
  )
}

resource "aws_route_table_association" "public" {
  for_each = contains(local.subnet_keys, "public") ? toset(local.azs) : toset([])

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}

# Elastic IP - used in NAT gateways (if configured)
resource "aws_eip" "nat" {
  for_each = toset(local.nat_configuration)
  domain   = "vpc"

  tags = merge(
    { Name = "nat-${local.subnet_names["public"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["public"].tags_aws, {})
  )
}

# NAT gateways (if configured)
resource "aws_nat_gateway" "main" {
  for_each = toset(local.nat_configuration)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(
    { Name = "nat-${local.subnet_names["public"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["public"].tags_aws, {})
  )

  depends_on = [
    aws_internet_gateway.main
  ]
}

# Internet gateway (if public subnets are created)
resource "aws_internet_gateway" "main" {
  count  = contains(local.subnet_keys, "public") ? 1 : 0
  vpc_id = local.vpc.id

  tags = merge(
    { Name = var.name },
    module.tags.tags_aws,
    try(module.subnet_tags["public"].tags_aws, {})
  )
}

# Egress-only IGW (if indicated)
resource "aws_egress_only_internet_gateway" "eigw" {
  count  = var.vpc_egress_only_internet_gateway ? 1 : 0
  vpc_id = local.vpc.id

  tags = merge(
    { "Name" = var.name },
    module.tags.tags_aws
  )
}

# Route: 0.0.0.0/0 from public subnets to the Internet gateway
resource "aws_route" "public_to_igw" {
  for_each = contains(local.subnet_keys, "public") && !local.public_ipv6only && local.connect_to_igw ? toset(local.azs) : toset([])

  route_table_id         = aws_route_table.public[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

# Route: ::/0 from public subnets to the Internet gateway
resource "aws_route" "public_ipv6_to_igw" {
  for_each = contains(local.subnet_keys, "public") && (local.public_ipv6only || local.public_dualstack) && local.connect_to_igw ? toset(local.azs) : toset([])

  route_table_id              = aws_route_table.public[each.key].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.main[0].id
}

# Route: IPv4 routes from public subnets to the Transit Gateway (if configured in var.transit_gateway_routes)
resource "aws_route" "public_to_tgw" {
  for_each = (contains(local.subnet_keys, "public") && contains(local.subnets_tgw_routed, "public")) ? toset(local.azs) : toset([])

  destination_cidr_block     = can(regex("^pl-", var.transit_gateway_routes["public"])) ? null : var.transit_gateway_routes["public"]
  destination_prefix_list_id = can(regex("^pl-", var.transit_gateway_routes["public"])) ? var.transit_gateway_routes["public"] : null

  transit_gateway_id = var.transit_gateway_id
  route_table_id     = aws_route_table.public[each.key].id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw
  ]
}

# Route: IPv6 routes from public subnets to the Transit Gateway (if configured in var.transit_gateway_ipv6_routes)
resource "aws_route" "ipv6_public_to_tgw" {
  for_each = (contains(local.subnet_keys, "public") && contains(local.ipv6_subnets_tgw_routed, "public")) ? toset(local.azs) : toset([])

  destination_ipv6_cidr_block = can(regex("^pl-", var.transit_gateway_ipv6_routes["public"])) ? null : var.transit_gateway_ipv6_routes["public"]
  destination_prefix_list_id  = can(regex("^pl-", var.transit_gateway_ipv6_routes["public"])) ? var.transit_gateway_ipv6_routes["public"] : null

  transit_gateway_id = var.transit_gateway_id
  route_table_id     = aws_route_table.public[each.key].id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw
  ]
}

# Route: IPv4 routes from public subnets to AWS Cloud WAN's core network (if configured in var.core_network_routes)
resource "aws_route" "public_to_cwan" {
  for_each = (contains(local.subnet_keys, "public") && contains(local.subnets_cwan_routed, "public") && local.create_cwan_routes) ? toset(local.azs) : toset([])

  destination_cidr_block     = can(regex("^pl-", var.core_network_routes["public"])) ? null : var.core_network_routes["public"]
  destination_prefix_list_id = can(regex("^pl-", var.core_network_routes["public"])) ? var.core_network_routes["public"] : null

  core_network_arn = var.core_network.arn
  route_table_id   = aws_route_table.public[each.key].id

  depends_on = [
    aws_networkmanager_vpc_attachment.cwan,
    aws_networkmanager_attachment_accepter.cwan
  ]
}

# Route: IPv6 routes from public subnets to AWS Cloud WAN's core network (if configured in var.core_network_routes)
resource "aws_route" "ipv6_public_to_cwan" {
  for_each = (contains(local.subnet_keys, "public") && contains(local.ipv6_subnets_cwan_routed, "public") && local.create_cwan_routes) ? toset(local.azs) : toset([])

  destination_ipv6_cidr_block = can(regex("^pl-", var.core_network_ipv6_routes["public"])) ? null : var.core_network_ipv6_routes["public"]
  destination_prefix_list_id  = can(regex("^pl-", var.core_network_ipv6_routes["public"])) ? var.core_network_ipv6_routes["public"] : null

  core_network_arn = var.core_network.arn
  route_table_id   = aws_route_table.public[each.key].id

  depends_on = [
    aws_networkmanager_vpc_attachment.cwan,
    aws_networkmanager_attachment_accepter.cwan
  ]
}

# ---------- PRIVATE SUBNETS CONFIGURATION ----------
# Private Subnets
resource "aws_subnet" "private" {
  for_each = toset(try(local.private_per_az, []))

  availability_zone                              = split("/", each.key)[1]
  vpc_id                                         = local.vpc.id
  cidr_block                                     = can(local.calculated_subnets[split("/", each.key)[0]][split("/", each.key)[1]]) ? local.calculated_subnets[split("/", each.key)[0]][split("/", each.key)[1]] : null
  ipv6_cidr_block                                = can(local.calculated_subnets_ipv6[split("/", each.key)[0]][split("/", each.key)[1]]) ? local.calculated_subnets_ipv6[split("/", each.key)[0]][split("/", each.key)[1]] : null
  ipv6_native                                    = contains(local.subnets_with_ipv6_native, split("/", each.key)[0]) ? true : false
  map_public_ip_on_launch                        = contains(local.subnets_with_ipv6_native, split("/", each.key)[0]) ? null : false
  assign_ipv6_address_on_creation                = contains(local.subnets_with_ipv6_native, split("/", each.key)[0]) ? true : try(var.subnets[each.key].assign_ipv6_address_on_creation, false)
  enable_resource_name_dns_aaaa_record_on_launch = contains(local.subnets_with_ipv6_native, split("/", each.key)[0]) ? true : try(var.subnets[each.key].enable_resource_name_dns_aaaa_record_on_launch, false)

  tags = merge(
    { Name = "${local.subnet_names[split("/", each.key)[0]]}-${split("/", each.key)[1]}" },
    module.tags.tags_aws,
    try(module.subnet_tags[split("/", each.key)[0]].tags_aws, {})
  )

  depends_on = [
    aws_vpc_ipv4_cidr_block_association.secondary
  ]
}

# Private subnet Route Table and association
resource "aws_route_table" "private" {
  for_each = toset(try(local.private_per_az, []))

  vpc_id = local.vpc.id

  tags = merge(
    { Name = "${local.subnet_names[split("/", each.key)[0]]}-${split("/", each.key)[1]}" },
    module.tags.tags_aws,
    try(module.subnet_tags[split("/", each.key)[0]].tags_aws, {})
  )
}

resource "aws_route_table_association" "private" {
  for_each = toset(try(local.private_per_az, []))

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

# Route: from the private subnet to the NAT gateway (if Internet access configured)
resource "aws_route" "private_to_nat" {
  for_each = toset(try(local.private_subnet_names_nat_routed, []))

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  # try to get nat for AZ, else use singular nat
  nat_gateway_id = local.nat_per_az[split("/", each.key)[1]].id
}

# Route: from the private subnet to the Egress-only IGW (if configured)
resource "aws_route" "private_to_egress_only" {
  for_each = toset(try(local.private_subnet_names_egress_routed, []))

  route_table_id              = aws_route_table.private[each.key].id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.eigw[0].id
}

# Route: IPv4 routes from private subnets to the Transit Gateway (if configured in var.transit_gateway_routes)
resource "aws_route" "private_to_tgw" {
  for_each = toset(local.private_subnet_key_names_tgw_routed)

  destination_cidr_block     = can(regex("^pl-", var.transit_gateway_routes[split("/", each.key)[0]])) ? null : var.transit_gateway_routes[split("/", each.key)[0]]
  destination_prefix_list_id = can(regex("^pl-", var.transit_gateway_routes[split("/", each.key)[0]])) ? var.transit_gateway_routes[split("/", each.key)[0]] : null

  route_table_id     = aws_route_table.private[each.key].id
  transit_gateway_id = var.transit_gateway_id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw
  ]
}

# Route: IPv6 routes from private subnets to the Transit Gateway (if configured in var.transit_gateway_ipv6_routes)
resource "aws_route" "ipv6_private_to_tgw" {
  for_each = toset(local.ipv6_private_subnet_key_names_tgw_routed)

  destination_ipv6_cidr_block = can(regex("^pl-", var.transit_gateway_ipv6_routes[split("/", each.key)[0]])) ? null : var.transit_gateway_ipv6_routes[split("/", each.key)[0]]
  destination_prefix_list_id  = can(regex("^pl-", var.transit_gateway_ipv6_routes[split("/", each.key)[0]])) ? var.transit_gateway_ipv6_routes[split("/", each.key)[0]] : null

  route_table_id     = aws_route_table.private[each.key].id
  transit_gateway_id = var.transit_gateway_id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw
  ]
}

# Route: IPv4 routes from private subnets to AWS Cloud WAN's core network (if configured in var.core_network_routes)
resource "aws_route" "private_to_cwan" {
  for_each = {
    for k, v in toset(local.private_subnet_key_names_cwan_routes) : k => v
    if local.create_cwan_routes
  }

  destination_cidr_block     = can(regex("^pl-", var.core_network_routes[split("/", each.key)[0]])) ? null : var.core_network_routes[split("/", each.key)[0]]
  destination_prefix_list_id = can(regex("^pl-", var.core_network_routes[split("/", each.key)[0]])) ? var.core_network_routes[split("/", each.key)[0]] : null

  core_network_arn = var.core_network.arn
  route_table_id   = aws_route_table.private[each.key].id

  depends_on = [
    aws_networkmanager_vpc_attachment.cwan,
    aws_networkmanager_attachment_accepter.cwan
  ]
}

# Route: IPv6 routes from private subnets to AWS Cloud WAN's core network (if configured in var.core_network_routes)
resource "aws_route" "ipv6_private_to_cwan" {
  for_each = {
    for k, v in toset(local.ipv6_private_subnet_keys_names_cwan_routes) : k => v
    if local.create_cwan_routes
  }

  destination_ipv6_cidr_block = can(regex("^pl-", var.core_network_ipv6_routes[split("/", each.key)[0]])) ? null : var.core_network_ipv6_routes[split("/", each.key)[0]]
  destination_prefix_list_id  = can(regex("^pl-", var.core_network_ipv6_routes[split("/", each.key)[0]])) ? var.core_network_ipv6_routes[split("/", each.key)[0]] : null

  core_network_arn = var.core_network.arn
  route_table_id   = aws_route_table.private[each.key].id

  depends_on = [
    aws_networkmanager_vpc_attachment.cwan,
    aws_networkmanager_attachment_accepter.cwan
  ]
}

# ---------- TRANSIT GATEWAY SUBNET CONFIGURATION ----------
# Transit Gateway Subnets
resource "aws_subnet" "tgw" {
  for_each = contains(local.subnet_keys, "transit_gateway") ? toset(local.azs) : toset([])

  availability_zone = each.key
  vpc_id            = local.vpc.id
  cidr_block        = local.calculated_subnets["transit_gateway"][each.key]
  ipv6_cidr_block   = can(local.calculated_subnets_ipv6["transit_gateway"][each.key]) ? local.calculated_subnets_ipv6["transit_gateway"][each.key] : null

  tags = merge(
    { Name = "${local.subnet_names["transit_gateway"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["transit_gateway"].tags_aws, {})
  )

}

# Transit Gateway subnet Route Table and association
resource "aws_route_table" "tgw" {
  for_each = contains(local.subnet_keys, "transit_gateway") ? toset(local.azs) : toset([])

  vpc_id = local.vpc.id

  tags = merge(
    { Name = "${local.subnet_names["transit_gateway"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["transit_gateway"].tags_aws, {})
  )
}

resource "aws_route_table_association" "tgw" {
  for_each = contains(local.subnet_keys, "transit_gateway") ? toset(local.azs) : toset([])

  subnet_id      = aws_subnet.tgw[each.key].id
  route_table_id = aws_route_table.tgw[each.key].id
}

# Route: from transit_gateway subnet to NAT gateway (if Internet access configured)
resource "aws_route" "tgw_to_nat" {
  for_each = (try(var.subnets.transit_gateway.connect_to_public_natgw == true, false) && contains(local.subnet_keys, "public")) ? toset(local.azs) : toset([])

  route_table_id         = aws_route_table.tgw[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  # try to get nat for AZ, else use singular nat
  nat_gateway_id = local.nat_per_az[each.key].id
}

# Transit Gateway VPC attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw" {
  count = contains(local.subnet_keys, "transit_gateway") ? 1 : 0

  subnet_ids         = values(aws_subnet.tgw)[*].id
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = local.vpc.id

  transit_gateway_default_route_table_association = try(var.subnets.transit_gateway.transit_gateway_default_route_table_association, null)
  transit_gateway_default_route_table_propagation = try(var.subnets.transit_gateway.transit_gateway_default_route_table_propagation, null)
  appliance_mode_support                          = try(var.subnets.transit_gateway.transit_gateway_appliance_mode_support, "disable")
  dns_support                                     = try(var.subnets.transit_gateway.transit_gateway_dns_support, "enable")
  ipv6_support                                    = local.tgw_dualstack ? "enable" : "disable"
}

# ---------- CORE NETWORK SUBNET CONFIGURATION ----------
# Core Network Subnets
resource "aws_subnet" "cwan" {
  for_each = contains(local.subnet_keys, "core_network") ? toset(local.azs) : toset([])

  availability_zone = each.key
  vpc_id            = local.vpc.id
  cidr_block        = local.calculated_subnets["core_network"][each.key]
  ipv6_cidr_block   = can(local.calculated_subnets_ipv6["core_network"][each.key]) ? local.calculated_subnets_ipv6["core_network"][each.key] : null

  tags = merge(
    { Name = "${local.subnet_names["core_network"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["core_network"].tags_aws, {})
  )
}

# Core Network subnet Route Table and association
resource "aws_route_table" "cwan" {
  for_each = contains(local.subnet_keys, "core_network") ? toset(local.azs) : toset([])

  vpc_id = local.vpc.id

  tags = merge(
    { Name = "${local.subnet_names["core_network"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["core_network"].tags_aws, {})
  )
}

resource "aws_route_table_association" "cwan" {
  for_each = contains(local.subnet_keys, "core_network") ? toset(local.azs) : toset([])

  subnet_id      = aws_subnet.cwan[each.key].id
  route_table_id = aws_route_table.cwan[each.key].id
}

# Route: from core_network subnet to NAT gateway (if Internet access configured)
resource "aws_route" "cwan_to_nat" {
  for_each = (try(var.subnets.core_network.connect_to_public_natgw == true, false) && contains(local.subnet_keys, "public")) ? toset(local.azs) : toset([])

  route_table_id         = aws_route_table.cwan[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  # try to get nat for AZ, else use singular nat
  nat_gateway_id = local.nat_per_az[each.key].id
}

# AWS Cloud WAN's Core Network VPC attachment
resource "aws_networkmanager_vpc_attachment" "cwan" {
  count = contains(local.subnet_keys, "core_network") ? 1 : 0

  core_network_id = var.core_network.id
  subnet_arns     = values(aws_subnet.cwan)[*].arn
  vpc_arn         = local.vpc.arn

  options {
    ipv6_support           = local.cwan_dualstack ? true : false
    appliance_mode_support = try(var.subnets.core_network.appliance_mode_support, false)
  }

  tags = merge(
    { Name = "${var.name}-vpc_attachment" },
    module.tags.tags_aws,
    module.subnet_tags["core_network"].tags_aws
  )
}

# Core Network's attachment acceptance (if required)
resource "aws_networkmanager_attachment_accepter" "cwan" {
  count = contains(local.subnet_keys, "core_network") && local.create_acceptance ? 1 : 0

  attachment_id   = aws_networkmanager_vpc_attachment.cwan[0].id
  attachment_type = "VPC"
}

# FLOW LOGS
module "flow_logs" {
  count = local.create_flow_logs ? 1 : 0

  source = "./modules/flow_logs"

  name                = var.name
  flow_log_definition = var.vpc_flow_logs
  vpc_id              = local.vpc.id

  tags = module.tags.tags_aws
}

# ---------- VPC LATTICE SERVICE NETWORK VPC ASSOCIATION ----------
resource "aws_vpclattice_service_network_vpc_association" "vpc_lattice_service_network_association" {
  count = local.lattice_association ? 1 : 0

  vpc_identifier             = aws_vpc.main[0].id
  service_network_identifier = var.vpc_lattice.service_network_identifier
  security_group_ids         = try(var.vpc_lattice.security_group_ids, null)

  tags = merge(
    module.tags.tags_aws,
    module.vpc_lattice_tags.tags_aws
  )
}