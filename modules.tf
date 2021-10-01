module "vpc_endpoints" {
  source                      = "aws-ia/vpc_endpoints/aws"
  version                     = "0.1.1"
  count                       = var.create_vpc ? length(var.enabled_interface_endpoints) > 0 || length(var.enabled_gateway_endpoints) > 0 ? 1 : 0 : 0
  vpc_id                      = aws_vpc.main[0].id
  subnet_ids                  = aws_subnet.private_b[*].id
  route_table_ids             = concat(aws_route_table.private_a[*].id, aws_route_table.private_b[*].id)
  enabled_interface_endpoints = var.enabled_interface_endpoints
  enabled_gateway_endpoints   = var.enabled_gateway_endpoints
  private_dns_enabled         = true
}
