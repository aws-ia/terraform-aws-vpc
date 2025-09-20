module "vpc" {
  source = "../../.."

  name       = "primary-az-vpc"
  cidr_block = "10.0.0.0/16"
  az_count   = var.az_count

  subnets = {
    public = {
      name_prefix               = "primary-vpc-public"
      netmask                   = 24
      nat_gateway_configuration = var.nat_gw_configuration
    }
    private = {
      netmask                 = 24
      connect_to_public_natgw = true
    }
  }
}

