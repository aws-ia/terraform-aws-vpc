data "aws_availability_zones" "current" {}

module "vpc" {
  # source  = "aws-ia/vpc/aws"
  # version = ">= 4.2.0"
  source = "../.."

  name       = "flowlogs"
  cidr_block = "10.0.0.0/20"
  az_count   = 2

  subnets = {
    public = {
      netmask                   = 24
      nat_gateway_configuration = "all_azs"
      tags = {
        subnet_type = "public"
      }
    }

    private = {
      netmask                 = 24
      connect_to_public_natgw = true
    }
  }

  vpc_flow_logs = {
    name_override        = "test"
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
  }
}

module "vpc2" {
  source = "../.."

  name       = "vpc-s3-logs"
  cidr_block = "10.0.0.0/16"
  az_count   = 2

  subnets = {
    endpoints = { netmask = 24 }
    workloads = { netmask = 24 }
  }

  vpc_flow_logs = {
    log_destination_type = "s3"
    destination_options = {
      file_format = "parquet"
    }
  }
}