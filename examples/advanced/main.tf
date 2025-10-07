
locals {
  azs = ["eu-west-1a", "eu-west-1c"]
}

# ---------- AMAZON VPC ----------
module "vpc" {
  source = "../.."

  name       = "advanced-example-vpc"
  cidr_block = "10.0.0.0/16"
  azs        = local.azs

  optimize_subnet_cidr_ranges = true

  subnets = {
    public = {
      netmask                   = 28
      nat_gateway_configuration = "single_az"
    }
    private        = { netmask = 24 }
    database       = { netmask = 27 }
    infrastructure = { netmask = 28 }
  }

  vpc_flow_logs = {
    log_destination_type = "s3"
    destination_options = {
      file_format = "parquet"
    }
  }
}

# ---------- VPC SECONDARY CIDR ----------
module "secondary_cidr_block" {
  source = "../.."

  name               = "advanced-example-secondary-cidr"
  vpc_id             = module.vpc.vpc_attributes.id
  create_vpc         = false
  vpc_secondary_cidr = true

  cidr_block = "10.100.0.0/16"
  azs        = [local.azs[0]]

  vpc_secondary_cidr_natgw = { for k, v in module.vpc.nat_gateway_attributes_by_az : k => { id = v.id } }

  subnets = {
    private_secondary_cidr = {
      netmask                 = 28
      connect_to_public_natgw = true
    }
  }
}