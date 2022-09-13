module "nat_gw_vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 2.4.0"

  name       = "nat-gw-options-vpc"
  cidr_block = "10.51.0.0/16"
  az_count   = 2

  subnets = {
    public = {
      name_prefix               = "public" # omit to prefix with "public"
      cidrs                     = ["10.51.0.0/24", "10.51.1.0/24"]
      nat_gateway_configuration = var.nat_gateway_configuration
      tags = {
        "tier" = "web"
      }
    }
    app = {
      name_prefix             = "app"
      cidrs                   = ["10.51.21.0/24", "10.51.22.0/24"]
      connect_to_public_natgw = var.route_to_nw
      tags = {
        "tier" = "app"
      }
    db = {
      name_prefix             = "db"
      cidrs                   = ["10.51.31.0/24", "10.51.32.0/24"]
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

