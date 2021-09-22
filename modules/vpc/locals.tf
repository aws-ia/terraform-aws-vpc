locals {
  max_private_subnet_length = max(
    length(local.private_subnet_a_cidrs),
    length(local.private_subnet_b_cidrs),
  )

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
  create_nat_gws         = var.create_vpc && var.create_igw && (var.create_nat_gateways_private_a || var.create_nat_gateways_private_b)

  # count variables
  vpc_count                   = var.create_vpc ? 1 : 0
  az_count                    = var.create_vpc ? length(local.availability_zones) : 0
  public_subnet_count         = var.create_vpc ? length(local.public_subnet_cidrs) : 0
  private_subnet_a_count      = var.create_vpc ? length(local.private_subnet_a_cidrs) : 0
  private_subnet_b_count      = var.create_vpc ? length(local.private_subnet_b_cidrs) : 0
  igw_count                   = var.create_igw && length(local.public_subnet_cidrs) > 0 ? local.vpc_count : 0
  nat_gateway_count           = local.create_nat_gws ? local.max_private_subnet_length : 0
  public_route_table_count    = length(local.public_subnet_cidrs) > 0 ? local.vpc_count : 0
  private_a_nacl_count        = length(local.private_subnet_a_cidrs) > 0 ? local.vpc_count : 0
  private_b_nacl_count        = length(local.private_subnet_b_cidrs) > 0 ? local.vpc_count : 0
  nat_gateway_private_a_count = var.create_vpc && var.create_igw && var.create_nat_gateways_private_a ? length(local.private_subnet_a_cidrs) : 0
  nat_gateway_private_b_count = var.create_vpc && var.create_igw && var.create_nat_gateways_private_b ? length(local.private_subnet_b_cidrs) : 0

  # flow log variables
  create_log_group      = var.create_vpc_flow_logs && var.log_destination_type != "s3" && var.log_destination == null
  create_log_bucket     = var.create_vpc_flow_logs && var.log_destination_type == "s3" && var.log_destination == null
  create_flow_log_iam_role     = var.create_vpc_flow_logs && var.log_destination_type != "s3" && var.flog_log_iam_role_arn == null
  log_destination       = (var.create_vpc_flow_logs && local.create_log_group ? aws_cloudwatch_log_group.flow_logs_log_group[0].arn : (local.create_log_bucket ? aws_s3_bucket.flow_logs_bucket[0].arn : var.log_destination))
  flog_log_iam_role_arn = local.create_flow_log_iam_role ? aws_iam_role.flow_logs_role[0].arn : var.flog_log_iam_role_arn
  log_format            = var.enriched_meta_data ? "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${pkt-src-aws-service} $${pkt-dst-aws-service} $${flow-direction} $${traffic-path}" : var.log_format
}
