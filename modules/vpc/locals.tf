locals {
  max_subnet_length = max(
    length(local.public_subnet_cidrs),
    length(local.private_subnet_a_cidrs),
    length(local.private_subnet_b_cidrs),
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
  name                   = var.name == null ? "tf-vpc-${random_string.vpc_name_suffix.id}" : var.name
  public_subnet_cidrs    = var.public_subnet_cidrs == null ? cidrsubnets(cidrsubnets(var.cidr, 2)[0], 2, 2, 2) : var.public_subnet_cidrs
  private_subnet_a_cidrs = var.private_subnet_a_cidrs == null ? cidrsubnets(cidrsubnets(var.cidr, 2, 2)[1], 2, 2, 2) : var.private_subnet_a_cidrs
  private_subnet_b_cidrs = var.private_subnet_b_cidrs == null ? [] : var.private_subnet_b_cidrs
  availability_zones     = var.availability_zones == null ? data.aws_availability_zones.available.names : var.availability_zones
}
