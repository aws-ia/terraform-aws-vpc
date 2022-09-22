locals {
  azs = slice(data.aws_availability_zones.current.names, 0, var.az_count)

  # references to module.calculate_subnets output
  calculated_subnets = module.calculate_subnets.subnets_by_type

  ##################################################################
  # Subnet names
  # A subnet's name is the subnet key by default but can be overrided by `name_prefix`.
  # Subnet names are used for Name tags.
  # resource name labels always use subnet key
  subnet_keys           = keys(var.subnets)
  subnet_names          = { for type, v in var.subnets : type => try(v.name_prefix, type) }
  subnet_keys_with_tags = { for type, v in var.subnets : type => v.tags if can(v.tags) }

  ##################################################################
  # Internal variables for mapping user input from var.subnets to HCL useful values
  # Notes:
  # - subnets map contains arbitrary amount of subnet "keys" which are both defined as the subnets type and default name (unless name_prefix is provided).
  # - resource name labels for subnet use the key as  private subnet keys are constructed

  singleton_subnet_types = ["public", "transit_gateway"]
  private_subnet_names   = setsubtract(local.subnet_keys, local.singleton_subnet_types)

  # constructed list of <private_subnet_key>/az
  private_per_az = flatten([for az in local.azs : [for subnet in local.private_subnet_names : "${subnet}/${az}"]])
  # list of private subnet keys with connect_to_public_natgw = true
  private_subnets_nat_routed = [for type in local.private_subnet_names : type if try(var.subnets[type].connect_to_public_natgw == true, false)]
  # private subnets with cidrs per az if connect_to_public_natgw = true ...  "privatetwo/us-east-1a"
  private_subnet_names_nat_routed = [for subnet in local.private_per_az : subnet if contains(local.private_subnets_nat_routed, split("/", subnet)[0])]

  # removed to support transit_gateway_routes
  #private_subnets_tgw_routed          = [for type in local.private_subnet_names : type if try(var.subnets[type].route_to_transit_gateway, "") != ""]
  #private_subnet_key_names_tgw_routed = [for subnet in local.private_per_az : subnet if contains(local.private_subnets_tgw_routed, split("/", subnet)[0])]
  subnets_tgw_routed                  = keys(var.transit_gateway_routes)
  private_subnet_key_names_tgw_routed = [for subnet in local.private_per_az : subnet if contains(local.subnets_tgw_routed, split("/", subnet)[0])]

  ##################################################################
  # NAT configurations options, maps user string input to HCL usable values. selected based on nat_gateway_configuration
  # null   = none
  # all    = local.azs
  # single = local.azs[0]
  nat_options = {
    "all_azs"   = local.azs
    "single_az" = [local.azs[0]]
    "none"      = [] # explicit "none" or omitted
  }
  nat_gateway_configuration = try(length(var.subnets.public.nat_gateway_configuration), 0) != 0 ? var.subnets.public.nat_gateway_configuration : "none"

  # if public subnets being built, check how many nats to create
  # options defined by `local.nat_options`
  # nat_configuration is a list of az names where a nat should be created
  nat_configuration = contains(local.subnet_keys, "public") ? local.nat_options[local.nat_gateway_configuration] : local.nat_options["none"]

  # used to reference which nat gateway id should be used in route
  nat_per_az = (contains(local.subnet_keys, "public") && !var.vpc_secondary_cidr) ? (
    # map of az : { id = <nat-id> }, ex: { "us-east-1a" : { "id": "nat-123" }}
    { for az in local.azs : az => {
      id : try(aws_nat_gateway.main[az].id, aws_nat_gateway.main[local.nat_configuration[0]].id) } if local.nat_gateway_configuration != "none"
    }) : (
    var.vpc_secondary_cidr ? var.vpc_secondary_cidr_natgw : {}
  )

  ##################################################################
  # Feature toggles for whether:
  # - create or reference a VPC
  # - get cidr block value from AWS IPAM
  # - create flow logs

  # # if var.vpc_id is passed, assume create = `false` and cidr comes from data.aws_vpc
  create_vpc = var.vpc_id == null ? true : false
  vpc        = local.create_vpc ? aws_vpc.main[0] : data.awscc_ec2_vpc.main[0]
  cidr_block = var.cidr_block == null ? aws_vpc.main[0].cidr_block : var.cidr_block

  create_flow_logs = (var.vpc_flow_logs == null || var.vpc_flow_logs.log_destination_type == "none") ? false : true
}

data "aws_availability_zones" "current" {}

# search for existing vpc with var.vpc_id if not creating
data "awscc_ec2_vpc" "main" {
  count = local.create_vpc ? 0 : 1
  id    = var.vpc_id
}

# santizes tags for both aws / awscc providers
# aws   tags = module.tags.tags_aws
# awscc tags = module.tags.tags
module "tags" {
  source  = "aws-ia/label/aws"
  version = "0.0.5"

  tags = var.tags
}

module "subnet_tags" {
  source  = "aws-ia/label/aws"
  version = "0.0.5"

  for_each = local.subnet_keys_with_tags

  tags = each.value
}
