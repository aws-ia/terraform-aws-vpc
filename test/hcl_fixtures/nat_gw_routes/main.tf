module "nat_gw_vpc" {
  source = "../../.."

  name       = "nat-gw-options-vpc"
  cidr_block = "10.51.0.0/16"
  az_count   = 2

  subnets = {

    public = {
      name_prefix               = "public" # omit to prefix with "public"
      netmask                   = 24
      nat_gateway_configuration = var.nat_gateway_configuration
      tags = {
        "tier" = "web"
      }
    }

    app = {
      name_prefix             = "app"
      netmask                 = 24
      connect_to_public_natgw = var.route_to_nw
      tags = {
        "tier" = "app"
      }
    }

    db = {
      name_prefix             = "db"
      netmask                 = 24
      connect_to_public_natgw = var.route_to_nw
      tags = {
        "tier" = "database"
      }
    }

  }

  tags = {
    "app" = "test"
  }
}
