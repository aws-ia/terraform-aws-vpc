
# ---------- AMAZON VPC ----------
module "vpc" {
  source = "../.."

  name       = "basic-example-vpc"
  cidr_block = "10.0.0.0/16"
  az_count   = 2

  vpc_assign_generated_ipv6_cidr_block = true
  vpc_egress_only_internet_gateway     = true

  subnets = {
    public = {
      netmask                   = 24
      nat_gateway_configuration = "all_azs"
      assign_ipv6_cidr          = true
    }
    private_ipv4_only = {
      netmask                 = 24
      connect_to_public_natgw = true
    }
    private_dualstack = {
      netmask                 = 24
      connect_to_public_natgw = true
      assign_ipv6_cidr        = true
      connect_to_eigw         = true
    }
    private_ipv6_only = {
      assign_ipv6_cidr = true
      ipv6_native      = true
      connect_to_eigw  = true
    }
  }

  vpc_flow_logs = {
    name_override        = "basic-vpc-flowlogs"
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 7
  }
}