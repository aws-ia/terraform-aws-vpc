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

  # map of subnet names to netmask values for looking up netmask by name
  netmasks_for_subnets = { for subnet in local.calculated_subnet_objects : subnet.name => subnet.netmask }

  # sorted list of netmasks from largest to smallest so we can efficiently use the ip address space
  sorted_subnet_netmasks = reverse(distinct(sort([
    for subnet in local.calculated_subnet_objects : format("%05d", subnet.netmask)
  ])))

  # list of subnet names sorted based on their netmask value (large to small)
  sorted_subnet_names = compact(flatten([
    for netmask in local.sorted_subnet_netmasks : [
      for subnet in local.calculated_subnet_objects :
      subnet.name if subnet.netmask == tonumber(netmask)
    ]
  ]))

  # list of subnet the original calculated subnet objects, but sorted based on their netmask value (large to small)
  sorted_subnet_objects = [
    for name in local.sorted_subnet_names : {
      name    = name
      netmask = local.netmasks_for_subnets[name]
    }
  ]

  # map of explicit cidrs to az
  explicit_cidrs_grouped = { for _, type in local.types_with_explicit : type => zipmap(var.azs, var.subnets[type].cidrs[*]) }
}

module "subnet_calculator" {
  count = length(local.types_to_calculate) == 0 ? 0 : 1

  source  = "drewmullen/subnets/cidr"
  version = "1.0.2"

  base_cidr_block = var.cidr
  networks        = var.optimize_subnet_cidr_ranges ? local.sorted_subnet_objects : local.calculated_subnet_objects
}
