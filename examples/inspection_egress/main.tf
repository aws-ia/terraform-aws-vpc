module "vpc" {
  source = "../.."

  vpc = {
    name = "inspection-egress-vpc"
  }

  addressing = {
    primary = { cidr_block = "100.64.0.0/16" }
  }

  availability_zones = {
    names = var.availability_zones
  }

  subnets = {
    public = {
      role = "public"
      ipv4 = {
        netmask    = 28
        cidr_index = 0
      }
      routing = {
        internet_gateway = true
      }
      public_options = {
        map_public_ip = false
      }
      tags = {
        Purpose = "nat-egress"
      }
    }

    firewall = {
      role = "private"
      ipv4 = {
        netmask    = 28
        cidr_index = 1
      }
      routing = {
        # After stateful inspection, outbound traffic reaches the AZ-local NAT.
        nat_gateway = true

        # Return traffic for spoke networks reaches the TGW. Managed prefix-list
        # IDs and IPv4 CIDRs may coexist in this typed destination list.
        transit_gateway_attachments = { inspection = [var.spoke_prefix_list_id] }
      }
      tags = {
        Purpose = "network-firewall-endpoints"
      }
    }

    tgw_attach = {
      role = "transit_gateway"
      ipv4 = {
        netmask    = 28
        cidr_index = 2
      }
      tags = {
        Purpose = "transit-gateway-attachment"
      }
    }
  }

  transit_gateway_attachments = {
    inspection = {
      subnet_group                    = "tgw_attach"
      id                              = var.transit_gateway_id
      default_route_table_association = false
      default_route_table_propagation = false

      # Mandatory for stateful inspection: both directions of each flow stay
      # pinned to the same AZ and therefore the same firewall endpoint.
      appliance_mode_support     = true
      dns_support                = true
      security_group_referencing = true
    }
  }

  nat_gateway = {
    mode         = "all_azs"
    subnet_group = "public"
  }

  tags = {
    Pattern = "centralized-inspection-with-egress"
  }
}

# Inputs for aws-ia/networkfirewall/aws. Keeping this as a local makes the Tier 1
# VPC composition plan-testable without forcing every consumer of this example to
# download or deploy a second registry module.
locals {
  network_firewall_composition = {
    vpc_id                  = module.vpc.vpc_id
    number_azs              = length(var.availability_zones)
    vpc_subnets             = module.vpc.subnet_ids_by_group_by_az["firewall"]
    network_firewall_policy = var.network_firewall_policy_arn
    routing_configuration = {
      centralized_inspection_with_egress = {
        connectivity_subnet_route_tables = module.vpc.route_table_ids_by_group_by_az["tgw_attach"]
        public_subnet_route_tables       = module.vpc.route_table_ids_by_group_by_az["public"]
        network_cidr_blocks              = var.spoke_network_cidr_blocks
      }
    }
  }
}

# Uncomment after selecting and pinning a reviewed aws-ia/networkfirewall/aws
# release and supplying network_firewall_policy_arn. The routing mode creates the
# TGW-subnet default routes to the AZ-local firewall endpoint and the public
# route-table return routes through that endpoint.
#
# module "network_firewall" {
#   source = "aws-ia/networkfirewall/aws"
#
#   network_firewall_name        = "inspection-egress"
#   network_firewall_description = "Centralized stateful inspection with egress"
#   network_firewall_policy      = local.network_firewall_composition.network_firewall_policy
#
#   vpc_id      = local.network_firewall_composition.vpc_id
#   number_azs  = local.network_firewall_composition.number_azs
#   vpc_subnets = local.network_firewall_composition.vpc_subnets
#
#   routing_configuration = local.network_firewall_composition.routing_configuration
#
#   tags = {
#     Pattern = "centralized-inspection-with-egress"
#   }
# }
