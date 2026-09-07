terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29"
    }
  }
}

module "vpc" {
  source = "../../.."

  vpc                = { name = "zonal-route-composition" }
  addressing         = { primary = { cidr_block = "10.140.0.0/16" } }
  availability_zones = { names = ["us-east-1a", "us-east-1b"] }

  subnets = {
    firewall = {
      role = "private"
      ipv4 = {
        cidrs_by_az = {
          us-east-1a = "10.140.0.0/28"
          us-east-1b = "10.140.0.16/28"
        }
      }
    }
    application = {
      role = "private"
      ipv4 = {
        cidrs_by_az = {
          us-east-1a = "10.140.10.0/24"
          us-east-1b = "10.140.11.0/24"
        }
      }
    }
  }

  routes = {
    inspected-default = {
      from_group  = "application"
      destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
      target = {
        type = "vpc_endpoint"
        ids_by_az = {
          for az, endpoint in terraform_data.firewall_endpoint : az => endpoint.id
        }
      }
    }
  }
}

# This resource stands in for Network Firewall: its instance keys and inputs
# consume subnet outputs from the VPC, while its computed IDs feed var.routes
# back into the same module call.
resource "terraform_data" "firewall_endpoint" {
  for_each = module.vpc.subnet_ids_by_group_by_az.firewall
  input    = each.value
}

output "composition_shape" {
  value = {
    endpoint_keys    = keys(terraform_data.firewall_endpoint)
    subnet_keys      = keys(module.vpc.subnet_ids_by_group_by_az.application)
    route_table_keys = keys(module.vpc.route_table_ids_by_group_by_az.application)
  }
}
