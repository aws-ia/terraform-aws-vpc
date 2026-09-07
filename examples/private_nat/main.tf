module "vpc" {
  source = "../.."

  vpc = {
    name = "private-nat-overlap-vpc"
  }

  addressing = {
    primary = {
      cidr_block = "10.42.0.0/16"
    }
    secondary = {
      translation = {
        ipv4 = { cidr_block = "100.64.0.0/20" }
      }
    }
  }

  availability_zones = {
    names = var.availability_zones
  }

  subnets = {
    workload = {
      role = "private"
      ipv4 = {
        cidrs_by_az = { "us-west-2a" = "10.42.0.0/24", "us-west-2b" = "10.42.1.0/24" }
      }
      # Workloads use the private NAT as their default next hop. Their original
      # 10/8 source addresses are translated before traffic reaches the TGW.
      routing = {
        nat_gateway = true
      }
    }

    nat-host = {
      role = "private"
      ipv4 = {
        cidrs_by_az        = { "us-west-2a" = "100.64.0.0/28", "us-west-2b" = "100.64.0.16/28" }
        secondary_cidr_key = "translation"
      }
      # The private NAT subnet forwards only the required remote 10/8 segments
      # to the TGW; no Internet Gateway or public EIP is involved.
      routing = {
        transit_gateway_attachments = { vpc = var.tgw_destination_cidrs }
      }
    }

    tgw = {
      role = "transit_gateway"
      ipv4 = {
        cidrs_by_az        = { "us-west-2a" = "100.64.0.32/28", "us-west-2b" = "100.64.0.48/28" }
        secondary_cidr_key = "translation"
      }
    }
  }

  transit_gateway_attachments = {
    vpc = {
      subnet_group                    = "tgw"
      id                              = var.transit_gateway_id
      default_route_table_association = false
      default_route_table_propagation = false
      appliance_mode_support          = false
      dns_support                     = true
      security_group_referencing      = true
    }
  }

  nat_gateway = {
    mode              = "all_azs"
    connectivity_type = "private"
    subnet_group      = "nat-host"
  }

  tags = {
    Pattern = "private-nat-overlapping-cidrs"
  }
}
