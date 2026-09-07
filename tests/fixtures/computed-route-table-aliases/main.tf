terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29"
    }
  }
}

resource "terraform_data" "shared_route_table" {
  input = "rtb-computed-shared"
}

module "vpc" {
  source = "../../.."

  vpc                = { name = "computed-route-table-aliases" }
  addressing         = { primary = { cidr_block = "10.141.0.0/16" } }
  availability_zones = { names = ["us-east-1a"] }

  subnets = {
    application = {
      role               = "private"
      ipv4               = { cidrs_by_az = { us-east-1a = "10.141.0.0/24" } }
      manage_route_table = false
      route_table_key    = "application"
      route_table_id     = terraform_data.shared_route_table.output
    }
    data = {
      role                                     = "isolated"
      ipv4                                     = { cidrs_by_az = { us-east-1a = "10.141.1.0/24" } }
      manage_route_table                       = false
      route_table_key                          = "data"
      route_table_id                           = terraform_data.shared_route_table.output
      isolated_accepts_uninspected_route_table = true
    }
  }

  routes = {
    inspected-default = {
      from_group  = "application"
      destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
      target      = { type = "vpc_endpoint", id = "vpce-documentation" }
    }
  }
}

output "ordering_shape" {
  value = {
    alias_keys       = sort(keys(module.vpc.resources.injected_route_table_ids))
    top_level_routes = sort(keys(module.vpc.resources.routes.top_level))
  }
}
