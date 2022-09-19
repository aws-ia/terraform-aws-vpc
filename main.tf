module "calculate_subnets" {
  source = "./modules/calculate_subnets"

  cidr = local.cidr_block
  azs  = local.azs

  subnets = var.subnets
}

resource "aws_vpc" "main" {
  count = local.create_vpc ? 1 : 0

  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.vpc_enable_dns_hostnames
  enable_dns_support   = var.vpc_enable_dns_support
  instance_tenancy     = var.vpc_instance_tenancy
  ipv4_ipam_pool_id    = var.vpc_ipv4_ipam_pool_id
  ipv4_netmask_length  = var.vpc_ipv4_netmask_length

  tags = merge(
    { "Name" = var.name },
    module.tags.tags_aws
  )
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  count = (var.vpc_secondary_cidr && !local.create_vpc) ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = local.cidr_block
  ipv4_ipam_pool_id = var.vpc_ipv4_ipam_pool_id
}

# Public Subnets

resource "aws_subnet" "public" {
  for_each = contains(local.subnet_keys, "public") ? toset(local.azs) : toset([])

  availability_zone = each.key
  vpc_id            = local.vpc.id
  cidr_block        = local.calculated_subnets["public"][each.key]

  tags = merge(
    { Name = "${local.subnet_names["public"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["public"].tags_aws, {})
  )
}

resource "awscc_ec2_route_table" "public" {
  for_each = contains(local.subnet_keys, "public") ? toset(local.azs) : toset([])

  vpc_id = local.vpc.id

  tags = concat(
    [{ "key" = "Name", "value" = "${local.subnet_names["public"]}-${each.key}" }],
    module.tags.tags,
    try(module.subnet_tags["public"].tags, [])
  )
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_configuration)
  vpc      = true

  tags = merge(
    { Name = "nat-${local.subnet_names["public"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["public"].tags_aws, {})
  )
}

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

resource "aws_internet_gateway" "main" {
  count  = contains(local.subnet_keys, "public") ? 1 : 0
  vpc_id = local.vpc.id

  tags = merge(
    { Name = var.name },
    module.tags.tags_aws,
    try(module.subnet_tags["public"].tags_aws, {})
  )
}

resource "aws_route" "public_to_igw" {
  for_each = contains(local.subnet_keys, "public") ? toset(local.azs) : toset([])

  route_table_id         = awscc_ec2_route_table.public[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

resource "awscc_ec2_subnet_route_table_association" "public" {
  for_each = contains(local.subnet_keys, "public") ? toset(local.azs) : toset([])

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = awscc_ec2_route_table.public[each.key].id
}

resource "aws_route" "public_to_tgw" {
  for_each = (contains(local.subnet_keys, "public") && contains(local.subnets_tgw_routed, "public")) ? toset(local.azs) : toset([])

  destination_cidr_block     = can(regex("^pl-", var.transit_gateway_routes["public"])) ? null : var.transit_gateway_routes["public"]
  destination_prefix_list_id = can(regex("^pl-", var.transit_gateway_routes["public"])) ? var.transit_gateway_routes["public"] : null

  transit_gateway_id = var.transit_gateway_id
  route_table_id     = awscc_ec2_route_table.public[each.key].id
}

# Private Subnets

resource "aws_subnet" "private" {
  for_each = toset(try(local.private_per_az, []))

  availability_zone       = split("/", each.key)[1]
  vpc_id                  = local.vpc.id
  cidr_block              = local.calculated_subnets[split("/", each.key)[0]][split("/", each.key)[1]]
  map_public_ip_on_launch = false

  tags = merge(
    { Name = "${local.subnet_names[split("/", each.key)[0]]}-${split("/", each.key)[1]}" },
    module.tags.tags_aws,
    try(module.subnet_tags[split("/", each.key)[0]].tags_aws, {})
  )

  depends_on = [
    aws_vpc_ipv4_cidr_block_association.secondary
  ]
}

resource "awscc_ec2_route_table" "private" {
  for_each = toset(try(local.private_per_az, []))

  vpc_id = local.vpc.id

  tags = concat(
    [{ "key" = "Name", "value" = "${local.subnet_names[split("/", each.key)[0]]}-${split("/", each.key)[1]}" }],
    module.tags.tags,
    try(module.subnet_tags[split("/", each.key)[0]].tags, [])
  )
}

resource "awscc_ec2_subnet_route_table_association" "private" {
  for_each = toset(try(local.private_per_az, []))

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = awscc_ec2_route_table.private[each.key].id
}

resource "aws_route" "private_to_nat" {
  for_each = toset(try(local.private_subnet_names_nat_routed, []))

  route_table_id         = awscc_ec2_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  # try to get nat for AZ, else use singular nat
  nat_gateway_id = local.nat_per_az[split("/", each.key)[1]].id
}

resource "aws_route" "private_to_tgw" {
  for_each = toset(local.private_subnet_key_names_tgw_routed)

  destination_cidr_block     = can(regex("^pl-", var.transit_gateway_routes[split("/", each.key)[0]])) ? null : var.transit_gateway_routes[split("/", each.key)[0]]
  destination_prefix_list_id = can(regex("^pl-", var.transit_gateway_routes[split("/", each.key)[0]])) ? var.transit_gateway_routes[split("/", each.key)[0]] : null

  route_table_id     = awscc_ec2_route_table.private[each.key].id
  transit_gateway_id = var.transit_gateway_id
}

# Transit Gateway Subnets

resource "aws_subnet" "tgw" {
  for_each = contains(local.subnet_keys, "transit_gateway") ? toset(local.azs) : toset([])

  availability_zone = each.key
  vpc_id            = local.vpc.id
  cidr_block        = local.calculated_subnets["transit_gateway"][each.key]

  tags = merge(
    { Name = "${local.subnet_names["transit_gateway"]}-${each.key}" },
    module.tags.tags_aws,
    try(module.subnet_tags["transit_gateway"].tags_aws, {})
  )

}

resource "awscc_ec2_route_table" "tgw" {
  for_each = contains(local.subnet_keys, "transit_gateway") ? toset(local.azs) : toset([])

  vpc_id = local.vpc.id

  tags = concat(
    [{ "key" = "Name", "value" = "${local.subnet_names["transit_gateway"]}-${each.key}" }],
    module.tags.tags,
    try(module.subnet_tags["transit_gateway"].tags, [])
  )
}

resource "awscc_ec2_subnet_route_table_association" "tgw" {
  for_each = contains(local.subnet_keys, "transit_gateway") ? toset(local.azs) : toset([])

  subnet_id      = aws_subnet.tgw[each.key].id
  route_table_id = awscc_ec2_route_table.tgw[each.key].id
}

resource "aws_route" "tgw_to_nat" {
  for_each = (try(var.subnets.transit_gateway.connect_to_public_natgw == true, false) && contains(local.subnet_keys, "public")) ? toset(local.azs) : toset([])


  route_table_id         = awscc_ec2_route_table.tgw[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  # try to get nat for AZ, else use singular nat
  nat_gateway_id = local.nat_per_az[each.key].id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw" {
  count = contains(local.subnet_keys, "transit_gateway") ? 1 : 0

  subnet_ids         = values(aws_subnet.tgw)[*].id
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = local.vpc.id

  transit_gateway_default_route_table_association = try(var.subnets.transit_gateway.transit_gateway_default_route_table_association, null)
  transit_gateway_default_route_table_propagation = try(var.subnets.transit_gateway.transit_gateway_default_route_table_propagation, null)
  appliance_mode_support                          = try(var.subnets.transit_gateway.transit_gateway_appliance_mode_support, "disable")
  dns_support                                     = try(var.subnets.transit_gateway.transit_gateway_dns_support, "enable")
}

resource "aws_ec2_transit_gateway_route_table_association" "tgw" {
  count = can(var.subnets.transit_gateway.transit_gateway_route_table_id) ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw[0].id
  transit_gateway_route_table_id = var.subnets.transit_gateway.transit_gateway_route_table_id
}

# Flow Logs

module "flow_logs" {
  count = local.create_flow_logs ? 1 : 0

  source = "./modules/flow_logs"

  name = var.name
  # see defaults.tf for local definition
  flow_log_defintion = local.flow_logs_definition
  vpc_id             = local.vpc.id
  tags               = module.tags.tags_aws
}
