
# VPC module
module "vpc" {
  source = "../.."

  name                                 = "vpc-ipv6-generated"
  cidr_block                           = "10.0.0.0/16"
  vpc_assign_generated_ipv6_cidr_block = true
  vpc_egress_only_internet_gateway     = true
  az_count                             = 2

  subnets = {
    public = {
      netmask                   = 24
      nat_gateway_configuration = "all_azs"
      assign_ipv6_cidr          = true
    }
    ipv4 = {
      netmask                 = 24
      connect_to_public_natgw = true
    }
    dualstack = {
      netmask                 = 24
      connect_to_public_natgw = true
      assign_ipv6_cidr        = true
      connect_to_eigw         = true
    }
    ipv6 = {
      ipv6_native      = true
      assign_ipv6_cidr = true
      connect_to_eigw  = true
    }
  }
}