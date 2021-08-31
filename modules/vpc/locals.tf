locals {
  max_subnet_length = max(
    length(var.private_subnets_a),
    length(var.private_subnets_b),
  )
  nat_gateway_count = local.max_subnet_length

  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = element(
    concat(
      aws_vpc.main.*.id,
      [""],
    ),
    0,
  )
}
