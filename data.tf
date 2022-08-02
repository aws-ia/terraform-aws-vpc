locals {
  azs = slice(data.aws_availability_zones.current.names, 0, var.az_count)

  # references to module.calculate_subnets output
  subnet_keys   = keys(var.subnets) #module.calculate_subnets.subnets_by_type
  calculated_subnets = module.calculate_subnets.subnets_by_type

  # default names if no name_prefix is passed
  subnet_names = { for type, v in var.subnets : type => try(v.name_prefix, type) }

  singleton_subnet_types = ["public", "transit_gateway"]
  private_subnet_names   = setsubtract(local.subnet_keys, local.singleton_subnet_types)

  # constructed list of <private_subnet_key>/az
  private_per_az = flatten([for az in local.azs : [for subnet in local.private_subnet_names : "${subnet}/${az}"]])
  # list of private subnet keys with route_to_nat = true
  private_subnets_nat_routed = [for type in local.private_subnet_names : type if try(var.subnets[type].route_to_nat, false)]
  # private subnets with cidrs per az if route_to_nat = true ...  "privatetwo/us-east-1a"
  private_subnet_names_nat_routed = [for subnet in local.private_per_az : subnet if contains(local.private_subnets_nat_routed, split("/", subnet)[0])]

  private_subnets_tgw_routed          = [for type in local.private_subnet_names : type if try(var.subnets[type].route_to_transit_gateway, false)]
  private_subnet_key_names_tgw_routed = [for subnet in local.private_per_az : subnet if contains(local.private_subnets_tgw_routed, split("/", subnet)[0])]

  # NAT configurations options, selected based on nat_gateway_configuration
  # null   = none
  # all    = local.azs
  # single = local.azs[0]
  nat_options = {
    "all_azs"   = local.azs
    "single_az" = [local.azs[0]]
    "none"      = [] # explicit "none" or omitted
  }
  # if public subnets being built, check how many nats to create
  # options defined by `local.nat_options`
  nat_configuration = contains(local.subnet_keys, "public") ? local.nat_options[try(var.subnets.public.nat_gateway_configuration, "none")] : local.nat_options["none"]

  # # if var.vpc_id is passed, assume create = `false` and cidr comes from data.aws_vpc
  create_vpc = var.vpc_id == null ? true : false
  vpc        = local.create_vpc ? aws_vpc.main[0] : data.awscc_ec2_vpc.main[0]
  cidr_block = var.vpc_ipv4_ipam_pool_id == null ? var.cidr_block : data.aws_vpc_ipam_preview_next_cidr.main[0].cidr

  create_flow_logs = (var.vpc_flow_logs == null || var.vpc_flow_logs.log_destination_type == "none") ? false : true
}

data "aws_availability_zones" "current" {}

# search for existing vpc with var.vpc_id if not creating
data "awscc_ec2_vpc" "main" {
  count = local.create_vpc ? 0 : 1
  id    = var.vpc_id
}

# preview next available cidr from ipam pool
data "aws_vpc_ipam_preview_next_cidr" "main" {
  count = var.vpc_ipv4_ipam_pool_id == null ? 0 : 1

  ipam_pool_id   = var.vpc_ipv4_ipam_pool_id
  netmask_length = var.vpc_ipv4_netmask_length
}

# santizes tags for both aws / awscc providers
# aws   tags = module.tags.tags_aws
# awscc tags = module.tags.tags
module "tags" {
  source  = "aws-ia/label/aws"
  version = "0.0.5"

  tags = var.tags
}
