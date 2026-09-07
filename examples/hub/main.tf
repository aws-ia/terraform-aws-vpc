module "vpc" {
  source = "../.."

  vpc = {
    name = "network-hub-vpc"
  }

  addressing = {
    primary = { cidr_block = "10.1.0.0/16" }
    secondary = {
      amazon-ipv6 = { ipv6 = { amazon_assigned = true } }
    }
  }

  availability_zones = {
    names = ["us-west-2a", "us-west-2b", "us-west-2c"]
  }

  subnets = {
    # Multiple public groups model distinct edge responsibilities.
    public = {
      role = "public"
      ipv4 = {
        cidrs_by_az = { "us-west-2a" = "10.1.0.0/24", "us-west-2b" = "10.1.1.0/24", "us-west-2c" = "10.1.2.0/24" }
      }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true, cidr_index = 0 }
      routing = {
        internet_gateway = true
      }
      public_options = {
        map_public_ip = false
      }
    }

    # A second public group reserves stable caller-owned edge identity.
    edge = {
      role = "public"
      ipv4 = {
        cidrs_by_az = { "us-west-2a" = "10.1.3.0/24", "us-west-2b" = "10.1.4.0/24", "us-west-2c" = "10.1.5.0/24" }
      }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true, cidr_index = 1 }
      routing = {
        internet_gateway = true
      }
      public_options = {
        map_public_ip = false
      }
      tags = { Purpose = "gwlb-endpoints" }
    }

    firewall = {
      role = "private"
      ipv4 = {
        cidrs_by_az = { "us-west-2a" = "10.1.16.0/28", "us-west-2b" = "10.1.16.16/28", "us-west-2c" = "10.1.16.32/28" }
      }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true, cidr_index = 2 }
      routing = {
        nat_gateway = true
        transit_gateway_attachments = {
          east = ["10.0.0.0/8", "172.16.0.0/12"]
          west = ["192.168.0.0/16"]
        }
        transit_gateway_attachments_ipv6 = {
          east = ["2001:db8:100::/48"]
        }
        # Route workload traffic to Cloud WAN from a non-attachment group.
        core_network      = ["100.64.0.0/10"]
        core_network_ipv6 = ["2001:db8:200::/48"]
      }
      routes = {
        security-services = {
          destination = { type = "ipv4_cidr", value = "198.18.0.0/15" }
          target      = { type = "vpc_peering", id = var.vpc_peering_connection_id }
        }
      }
      tags = { Purpose = "network-firewall-endpoints" }
    }

    tgw = {
      role = "transit_gateway"
      ipv4 = {
        netmask    = 28
        cidr_index = 64 # 10.1.24.0/28+, outside all explicit ranges
      }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true, cidr_index = 3 }
      routing = {
        nat_gateway = true
      }
    }

    cwan = {
      role = "core_network"
      ipv4 = {
        netmask    = 28
        cidr_index = 65 # 10.1.24.96/28+, outside all explicit ranges
      }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true, cidr_index = 4 }
      core_network_options = {
        id                 = var.core_network_id
        arn                = var.core_network_arn
        appliance_mode     = false
        require_acceptance = true
        accept_attachment  = true
      }
    }
  }

  # The endpoint producer can consume subnet outputs from this module and return
  # one existing GWLB endpoint ID per AZ without creating a dependency cycle.
  routes = {
    inspected-services = {
      from_group  = "firewall"
      destination = { type = "ipv4_cidr", value = "203.0.113.0/24" }
      target = {
        type      = "vpc_endpoint"
        ids_by_az = var.gwlb_endpoint_ids_by_az
      }
    }
  }

  # Stable caller keys are attachment identity and are also selected by routes.
  transit_gateway_attachments = {
    east = {
      subnet_group                    = "tgw"
      id                              = var.transit_gateway_ids["east"]
      default_route_table_association = false
      default_route_table_propagation = false
      appliance_mode_support          = true
      dns_support                     = true
      security_group_referencing      = true
    }
    west = {
      subnet_group                    = "tgw"
      id                              = var.transit_gateway_ids["west"]
      default_route_table_association = false
      default_route_table_propagation = false
      appliance_mode_support          = true
      dns_support                     = true
      security_group_referencing      = true
    }
  }

  nat_gateway = {
    mode = "regional"
    eip = {
      mode           = "existing"
      allocation_ids = var.nat_eip_allocation_ids
    }
  }

  # The module creates both attachments. The Firehose stream and its S3/IAM
  # dependencies are externally managed and injected by ARN.
  flow_logs = {
    network = {
      destination_type = "kinesis"
      destination_arn  = var.flow_log_destination_arn
      traffic_type     = "ALL"
    }
  }

  tags = {
    Environment = "production"
    Role        = "network-hub"
  }
}

# ─── Private NAT example (inspection VPC pattern) ─────────────────────────
# Demonstrates connectivity_type = "private" — NAT without public EIP.

module "inspection_vpc" {
  source = "../.."

  vpc = {
    name = "inspection-vpc"
  }

  addressing = {
    primary = { cidr_block = "100.64.0.0/16" }
  }

  availability_zones = {
    names = ["us-west-2a", "us-west-2b"]
  }

  subnets = {
    firewall = {
      role = "private"
      ipv4 = { netmask = 24 }
      routing = {
        nat_gateway = true
        transit_gateway_attachments = {
          inspection = ["10.0.0.0/8"]
        }
      }
    }

    tgw = {
      role = "transit_gateway"
      ipv4 = { netmask = 28 }
    }

    # Private NAT needs a subnet to live in — but private NAT doesn't require
    # a public subnet, it can be placed in any subnet. We use a dedicated one.
    nat-host = {
      role = "private"
      ipv4 = { netmask = 28 }
    }
  }

  transit_gateway_attachments = {
    inspection = {
      subnet_group = "tgw"
      id           = var.transit_gateway_ids["east"]
    }
  }

  nat_gateway = {
    mode              = "all_azs"
    connectivity_type = "private"
    subnet_group      = "nat-host"
  }

  tags = {
    Environment = "production"
    Role        = "inspection"
  }
}
