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
  name                   = var.name == null ? length(random_string.vpc_name_suffix) > 0 ? "tf-vpc-${random_string.vpc_name_suffix[0].id}" : "" : var.name
  public_subnet_cidrs    = var.public_subnet_cidrs == null ? cidrsubnets(cidrsubnets(var.cidr, 2)[0], 2, 2, 2) : var.public_subnet_cidrs
  private_subnet_a_cidrs = var.private_subnet_a_cidrs == null ? cidrsubnets(cidrsubnets(var.cidr, 2, 2)[1], 2, 2, 2) : var.private_subnet_a_cidrs
  private_subnet_b_cidrs = var.private_subnet_b_cidrs == null ? [] : var.private_subnet_b_cidrs
  availability_zones     = var.availability_zones == null ? data.aws_availability_zones.available.names : var.availability_zones

  # count variables
  vpc_count                   = var.create_vpc ? 1 : 0
  az_count                    = var.create_vpc ? length(local.availability_zones) : 0
  public_subnet_count         = var.create_vpc ? length(local.public_subnet_cidrs) : 0
  private_subnet_a_count      = var.create_vpc ? length(local.private_subnet_a_cidrs) : 0
  private_subnet_b_count      = var.create_vpc ? length(local.private_subnet_b_cidrs) : 0
  igw_count                   = var.create_igw && length(local.public_subnet_cidrs) > 0 ? local.vpc_count : 0
  public_route_table_count    = length(local.public_subnet_cidrs) > 0 ? local.vpc_count : 0
  private_a_nacl_count        = length(local.private_subnet_a_cidrs) > 0 ? local.vpc_count : 0
  private_b_nacl_count        = length(local.private_subnet_b_cidrs) > 0 ? local.vpc_count : 0
  nat_gateway_private_a_count = var.create_vpc && var.create_nat_gateways_private_a ? length(local.private_subnet_a_cidrs) : 0
  nat_gateway_private_b_count = var.create_vpc && var.create_nat_gateways_private_b ? length(local.private_subnet_b_cidrs) : 0
}
