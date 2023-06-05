output "subnets_by_type" {
  description = "Outputs subnets prefixes by type (private, public). Derived from split(var.separator, <subnet_name>)."
  value       = merge(try(local.explicit_cidrs_grouped, {}), try(module.subnet_calculator[0].grouped_by_separator, {}))
}

output "subnets_with_ipv6_native" {
  description = "Outputs types of subnets that are ipv6_native."
  value       = local.types_ipv6_native
}