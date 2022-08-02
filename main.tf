module "calculate_subnets" {
  source = "./modules/calculate_subnets"

  cidr = local.cidr_block
  azs  = local.azs

  subnets = var.subnets
}

resource "aws_vpc" "main" {
  count = local.create_vpc ? 1 : 0

  cidr_block           = local.cidr_block
  enable_dns_hostnames = var.vpc_enable_dns_hostnames
  enable_dns_support   = var.vpc_enable_dns_support
  instance_tenancy     = var.vpc_instance_tenancy
  ipv4_ipam_pool_id    = var.vpc_ipv4_ipam_pool_id

  tags = merge({
    "Name" = var.name
    },
  module.tags.tags_aws)

  lifecycle {
    ignore_changes = [cidr_block]
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  count = (var.vpc_secondary_cidr && !local.create_vpc) ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = local.cidr_block
  ipv4_ipam_pool_id = var.vpc_ipv4_ipam_pool_id

  lifecycle {
    ignore_changes = [cidr_block]
  }
}

# Public Subnets

resource "aws_subnet" "public" {
  for_each = try(local.subnets.public, {})

  availability_zone = each.key
  vpc_id            = local.vpc.id
  cidr_block        = each.value

  tags = merge({
    Name = "${local.subnet_names["public"]}-${each.key}" },
    module.tags.tags_aws
  )

  lifecycle {
    ignore_changes = [cidr_block]
  }
}

resource "awscc_ec2_route_table" "public" {
  for_each = try(local.subnets.public, {})

  vpc_id = local.vpc.id

  tags = concat(
    [{ "key" = "Name", "value" = "${local.subnet_names["public"]}-${each.key}" }],
    module.tags.tags
  )
}

resource "awscc_ec2_subnet_route_table_association" "public" {
  for_each = try(local.subnets.public, {})

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = awscc_ec2_route_table.public[each.key].id
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_configuration)
  vpc      = true

  tags = merge({
    Name = "nat-${local.subnet_names["public"]}-${each.key}"
  }, module.tags.tags_aws)
}

resource "aws_nat_gateway" "main" {
  for_each = toset(local.nat_configuration)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge({
    Name = "nat-${local.subnet_names["public"]}-${each.key}" },
  module.tags.tags_aws)

  depends_on = [
    aws_internet_gateway.main
  ]
}

resource "aws_internet_gateway" "main" {
  count  = contains(keys(local.subnets), "public") ? 1 : 0
  vpc_id = local.vpc.id

  tags = merge({
    Name = var.name },
  module.tags.tags_aws)
}

resource "aws_route" "public_to_igw" {
  for_each = try(local.subnets.public, {})

  route_table_id         = awscc_ec2_route_table.public[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

resource "aws_route" "public_to_tgw" {
  for_each = try(var.subnets.public.route_to_transit_gateway, null) != null ? local.subnets.public : {}

  destination_cidr_block     = can(regex("^pl-", var.subnets.public.route_to_transit_gateway)) ? null : var.subnets.public.route_to_transit_gateway
  destination_prefix_list_id = can(regex("^pl-", var.subnets.public.route_to_transit_gateway)) ? var.subnets.public.route_to_transit_gateway : null

  transit_gateway_id = var.subnets.transit_gateway.transit_gateway_id
  route_table_id     = awscc_ec2_route_table.public[split(":", each.key)[0]].id
}

# Private Subnets

resource "aws_subnet" "private" {
  for_each = toset(try(local.private_per_az, []))

  availability_zone       = split("/", each.key)[1]
  vpc_id                  = local.vpc.id
  cidr_block              = local.subnets[split("/", each.key)[0]][split("/", each.key)[1]]
  map_public_ip_on_launch = false

  tags = merge({
    Name = "${local.subnet_names[split("/", each.key)[0]]}-${split("/", each.key)[1]}" },
  module.tags.tags_aws)

  depends_on = [
    aws_vpc_ipv4_cidr_block_association.secondary
  ]
  lifecycle {
    ignore_changes = [cidr_block]
  }
}

resource "awscc_ec2_route_table" "private" {
  for_each = toset(try(local.private_per_az, []))

  vpc_id = local.vpc.id

  tags = concat(
    [{ "key" = "Name", "value" = "${local.subnet_names[split("/", each.key)[0]]}-${split("/", each.key)[1]}" }],
    module.tags.tags
  )
}

resource "awscc_ec2_subnet_route_table_association" "private" {
  for_each = toset(try(local.private_per_az, []))

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = awscc_ec2_route_table.private[each.key].id
}

resource "aws_route" "private_to_nat" {
  # if `route_to_nat` exists & `true` apply to private subnets per az, else do not apply
  for_each = toset(try(local.private_subnet_names_nat_routed, []))

  route_table_id         = awscc_ec2_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  # try to get nat for AZ, else use singular nat
  nat_gateway_id = try(aws_nat_gateway.main[split("/", each.key)[1]].id, aws_nat_gateway.main[local.nat_configuration[0]].id)
}

resource "aws_route" "private_to_tgw" {
  for_each = toset(try(local.private_subnet_key_names_tgw_routed, []))

  route_table_id         = awscc_ec2_route_table.private[each.key].id
  destination_cidr_block = var.subnets[split("/", each.key)[0]].route_to_transit_gateway[0]
  transit_gateway_id     = var.subnets.transit_gateway.transit_gateway_id
}

# Transit Gateway Subnets

resource "aws_subnet" "tgw" {
  for_each = try(local.subnets.transit_gateway, {})

  availability_zone = each.key
  vpc_id            = local.vpc.id
  cidr_block        = each.value

  tags = merge({
    Name = "${local.subnet_names["transit_gateway"]}-${each.key}" },
    module.tags.tags_aws
  )
  lifecycle {
    ignore_changes = [cidr_block]
  }
}

resource "awscc_ec2_route_table" "tgw" {
  for_each = try(local.subnets.transit_gateway, {})

  vpc_id = local.vpc.id

  tags = concat(
    [{ "key" = "Name", "value" = "${local.subnet_names["transit_gateway"]}-${each.key}" }],
    module.tags.tags
  )
}

resource "awscc_ec2_subnet_route_table_association" "tgw" {
  for_each = try(local.subnets.transit_gateway, {})

  subnet_id      = aws_subnet.tgw[each.key].id
  route_table_id = awscc_ec2_route_table.tgw[each.key].id
}

resource "aws_route" "tgw_to_nat" {
  # if `route_to_nat` exists & `true` apply to private subnets per az, else do not apply
  for_each = try(var.subnets.transit_gateway.route_to_nat, false) ? try(local.subnets.public, {}) : {}

  route_table_id         = awscc_ec2_route_table.tgw[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  # try to get nat for AZ, else use singular nat
  nat_gateway_id = try(aws_nat_gateway.main[each.key].id, aws_nat_gateway.main[local.nat_configuration[0]].id)
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw" {
  count = contains(keys(local.subnets), "transit_gateway") ? 1 : 0

  subnet_ids         = values(aws_subnet.tgw)[*].id
  transit_gateway_id = var.subnets.transit_gateway.transit_gateway_id
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
