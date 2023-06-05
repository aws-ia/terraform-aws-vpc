locals {
  # group subnets by type and create names for each type
  type_grouped_named_subnets_to_build = { for name, subnet_definition in var.subnets : name => [for _, az in var.azs : "${name}/${az}"] }
  # which network groups require calculating subnet
  types_to_calculate = [for type, subnet_definition in var.subnets : type if can(subnet_definition.netmask)]
  types_ipv6_native  = [for type, subnet_definition in var.subnets : type if can(subnet_definition.ipv6_native)]
  # network groups that are set explicitly
  types_with_explicit_and_ipv6 = setsubtract(keys(var.subnets), local.types_to_calculate)
  types_with_explicit          = setsubtract(local.types_with_explicit_and_ipv6, local.types_ipv6_native)


  # network object to pass to calculating module
  calculated_subnet_objects = flatten([for _, type in local.types_to_calculate : [for _, v in local.type_grouped_named_subnets_to_build[type] : {
    "name"    = v
    "netmask" = var.subnets[type].netmask
    }
  ]])

  # map of explicit cidrs to az
  explicit_cidrs_grouped = { for _, type in local.types_with_explicit : type => zipmap(var.azs, var.subnets[type].cidrs[*]) }
}

module "subnet_calculator" {
  count = length(local.types_to_calculate) == 0 ? 0 : 1

  source  = "drewmullen/subnets/cidr"
  version = "1.0.2"

  base_cidr_block = var.cidr
  networks        = local.calculated_subnet_objects
}

