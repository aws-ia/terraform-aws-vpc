
data "aws_availability_zones" "current" {}

# ---------- AWS TRANSIT GATEWAY ----------
resource "aws_ec2_transit_gateway" "tgw" {
  description = "example"
}

# ---------- MANAGED PREFIX LIST ----------
resource "aws_ec2_managed_prefix_list" "prefix_list" {
  name           = "All VPC CIDR-s"
  address_family = "IPv4"
  max_entries    = length(var.prefixes)

  dynamic "entry" {
    for_each = var.prefixes

    content {
      cidr        = entry.value
      description = entry.key
    }
  }
}

# ---------- AMAZON VPC ----------
module "vpc" {
  source = "../.."

  name                                 = "tgw-example-vpc"
  cidr_block                           = "10.0.0.0/16"
  vpc_assign_generated_ipv6_cidr_block = true
  az_count                             = 2

  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  transit_gateway_routes = {
    private_ipv4      = "192.168.0.0/16"
    private_dualstack = aws_ec2_managed_prefix_list.prefix_list.id
  }
  transit_gateway_ipv6_routes = {
    private_dualstack = "::/0"
  }

  subnets = {
    private_ipv4 = { netmask = 28 }
    private_dualstack = {
      netmask          = 24
      assign_ipv6_cidr = true
    }
    transit_gateway = {
      netmask                                            = 28
      assign_ipv6_cidr                                   = true
      transit_gateway_default_route_table_association    = false
      transit_gateway_default_route_table_propagation    = false
      transit_gateway_appliance_mode_support             = "enable"
      transit_gateway_dns_support                        = "disable"
      transit_gateway_security_group_referencing_support = "enable"
    }
  }
}
