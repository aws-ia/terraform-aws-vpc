terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29"
    }
  }
}

variable "accept_uninspected" {
  type    = bool
  default = false
}

resource "terraform_data" "route_table_id" {
  input = "rtb-computed"
}

module "vpc" {
  source = "../../.."

  vpc                = { name = "computed-isolated-route-table" }
  addressing         = { primary = { cidr_block = "10.108.0.0/16" } }
  availability_zones = { names = ["us-east-1a"] }
  subnets = {
    data = {
      role                                     = "isolated"
      ipv4                                     = { cidrs_by_az = { us-east-1a = "10.108.0.0/24" } }
      manage_route_table                       = false
      route_table_key                          = "isolated"
      route_table_id                           = terraform_data.route_table_id.output
      isolated_accepts_uninspected_route_table = var.accept_uninspected
    }
  }
}

output "route_table_association_count" {
  value = length(module.vpc.resources.route_table_associations)
}
