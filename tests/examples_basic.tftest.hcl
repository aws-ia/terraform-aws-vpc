run "validate" {
  command = apply
  module {
    source = "./examples/basic"
  }

  # Resolves https://github.com/aws-ia/terraform-aws-vpc/issues/177:
  # the new `private_subnet_attributes_by_az_with_nat` output must include only
  # subnets routed through a NAT gateway (basic example: `private_ipv4_only`,
  # `private_dualstack`) and exclude isolated subnets (`private_ipv6_only`).
  assert {
    condition     = alltrue([for k, _ in module.vpc.private_subnet_attributes_by_az_with_nat : startswith(k, "private_ipv4_only/") || startswith(k, "private_dualstack/")])
    error_message = "private_subnet_attributes_by_az_with_nat must contain only NAT-routed subnets."
  }

  assert {
    condition     = alltrue([for k, _ in module.vpc.private_subnet_attributes_by_az_with_nat : !startswith(k, "private_ipv6_only/")])
    error_message = "private_subnet_attributes_by_az_with_nat must NOT contain isolated subnets (private_ipv6_only has no NAT route)."
  }
}