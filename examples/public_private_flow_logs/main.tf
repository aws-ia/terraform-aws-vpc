data "aws_availability_zones" "current" {}

module "vpc1" {
  source  = "aws-ia/vpc/aws"
  version = "= 4.4.0"

  # For testing purposes, uncomment the line below and comment the "source" and "version" lines above
  #source = "../.."

  name       = "vpc-cw-logs"
  cidr_block = "10.0.0.0/16"
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
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
  }
}

module "vpc2" {
  source  = "aws-ia/vpc/aws"
  version = "= 4.4.0"

  # For testing purposes, uncomment the line below and comment the "source" and "version" lines above
  #source = "../.."

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
