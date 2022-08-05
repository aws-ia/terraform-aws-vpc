module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 2.0.0"

  name       = "multi-az-vpc"
  cidr_block = "10.0.0.0/20"
  az_count   = 3

  subnets = {
    public = {
      name_prefix               = "my-public" # omit to prefix with "public"
      netmask                   = 24
      nat_gateway_configuration = "all_azs" # options: "single_az", "none"
    }

    private = {
      # omitting name_prefix defaults value to "private"
      # name_prefix  = "private"
      netmask                 = 24
      connect_to_public_natgw = true
    }
  }

  vpc_flow_logs = {
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
    kms_key_id           = var.kms_key_id
  }
}
