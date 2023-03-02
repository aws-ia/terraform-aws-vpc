locals {
  # group subnets by type and create names for each type
  type_grouped_named_subnets_to_build = { for name, subnet_definition in var.subnets : name => [for _, az in var.azs : "${name}/${az}"] }
  # which network groups require calculating subnet
  subnets_to_calculate = [for type, subnet_definition in var.subnets : type if can(subnet_definition.assign_ipv6_address_on_creation)]
  # network groups that are set explicitly
  types_with_no_ipv6 = setsubtract(keys(var.subnets), local.subnets_to_calculate)

  # network object to pass to calculating module
  calculated_subnet_objects = flatten([for _, type in local.subnets_to_calculate : [for _, v in local.type_grouped_named_subnets_to_build[type] : {
    "name"    = v
    "netmask" = 64
    }
  ]])
}

module "subnet_calculator" {
  count = local.subnets_to_calculate == [] ? 0 : 1

  source  = "drewmullen/subnets/cidr"
  version = "1.0.2"

  base_cidr_block = var.cidr_ipv6
  networks        = local.calculated_subnet_objects
}
