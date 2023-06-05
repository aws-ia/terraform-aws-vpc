output "subnets_ipv6" {
  description = "Outputs subnets prefixes by type (private, public). Derived from split(var.separator, <subnet_name>)."
  value       = merge(try(local.explicit_cidrs_grouped, {}), try(module.subnet_calculator[0].grouped_by_separator, {}))
}