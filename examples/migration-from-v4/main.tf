# This skeleton preserves the v4 reserved group names so every deprecated
# Tier 2 output keeps its exact v4 key shape during the transition.
module "vpc" {
  source = "../.."

  vpc = {
    name             = "migration-example"
    igw_name_format  = "{vpc}-igw" # v4: "${var.name}-igw"
    eigw_name_format = "{vpc}"     # v4: var.name
  }

  addressing = {
    primary = { cidr_block = "10.42.0.0/16" }
    secondary = {
      v4-ipv6 = { ipv6 = { amazon_assigned = true } }
    }
  }

  availability_zones = {
    names = ["us-east-1a", "us-east-1b"]
  }

  subnets = {
    public = {
      role        = "public"
      name_format = "{group}-{az}" # v4: "${name_prefix || key}-${az}"
      ipv4        = { cidrs_by_az = { "us-east-1a" = "10.42.0.0/24", "us-east-1b" = "10.42.1.0/24" } }
      # Replace with the prefixes already recorded in v4 state.
      ipv6 = { secondary_cidr_key = "v4-ipv6", cidrs_by_az = { "us-east-1a" = "2001:db8:4200:1::/64", "us-east-1b" = "2001:db8:4200:2::/64" }, auto_assign = true }
      routing = {
        internet_gateway     = true
        transit_gateway      = ["10.0.0.0/8"]
        transit_gateway_ipv6 = ["2001:db8:100::/48"]
        core_network         = ["100.64.0.0/10"]
        core_network_ipv6    = ["2001:db8:300::/48"]
      }
      public_options = { map_public_ip = true }
    }

    app = {
      role        = "private"
      name_format = "{group}-{az}"
      ipv4        = { cidrs_by_az = { "us-east-1a" = "10.42.16.0/20", "us-east-1b" = "10.42.32.0/20" } }
      ipv6        = { secondary_cidr_key = "v4-ipv6", cidrs_by_az = { "us-east-1a" = "2001:db8:4200:10::/64", "us-east-1b" = "2001:db8:4200:11::/64" }, auto_assign = true }
      routing = {
        nat_gateway          = true
        egress_only_igw      = true
        transit_gateway      = ["172.16.0.0/12"]
        transit_gateway_ipv6 = ["2001:db8:200::/48"]
        core_network         = ["192.168.0.0/16"]
        core_network_ipv6    = ["2001:db8:400::/48"]
      }
    }

    transit_gateway = {
      role        = "transit_gateway"
      name_format = "{group}-{az}"
      ipv4        = { cidrs_by_az = { "us-east-1a" = "10.42.240.0/28", "us-east-1b" = "10.42.240.16/28" } }
      ipv6        = { secondary_cidr_key = "v4-ipv6", cidrs_by_az = { "us-east-1a" = "2001:db8:4200:f0::/64", "us-east-1b" = "2001:db8:4200:f1::/64" } }
      routing     = { nat_gateway = true }
      transit_gateway_options = {
        id = "tgw-0123456789abcdef0"
      }
    }

    core_network = {
      role        = "core_network"
      name_format = "{group}-{az}"
      ipv4        = { cidrs_by_az = { "us-east-1a" = "10.42.241.0/28", "us-east-1b" = "10.42.241.16/28" } }
      ipv6        = { secondary_cidr_key = "v4-ipv6", cidrs_by_az = { "us-east-1a" = "2001:db8:4200:f2::/64", "us-east-1b" = "2001:db8:4200:f3::/64" } }
      routing     = { nat_gateway = true }
      core_network_options = {
        id  = "cnet-0123456789abcdef0"
        arn = "arn:aws:networkmanager::123456789012:core-network/cnet-0123456789abcdef0"
      }
    }
  }

  nat_gateway = {
    mode         = "all_azs"
    subnet_group = "public"
    name_format  = "nat-{group}-{az}" # v4 EIP and NAT Name formula
  }

  flow_logs = {
    default = {
      destination_type = "cloudwatch"
      traffic_type     = "ALL"
      name_format      = "{vpc}" # v4 Flow Log Name tag: var.name

      # Replace both values with the exact v4 state values before planning.
      # The log group uses the root declarative handoff below; the role uses a moved block.
      role_name_prefix = "migration-example-cw-access-role-"
      cloudwatch_options = {
        name        = var.v4_flow_log_group_name
        name_format = "" # v4 generated log group had no Name tag
      }
    }
  }

  vpc_lattice = {
    enabled                    = true
    service_network_identifier = "sn-0123456789abcdef0"
  }

  tags = {
    ManagedBy = "terraform"
  }
}

# Migration-only root blocks (Terraform >= 1.7).
#
# Copy this example into the caller root and uncomment both `removed`
# blocks plus the log-group `import` block. When the v4 VPC has IPv6, also
# uncomment the association import and capture `v4_ipv6_association_id` plus the
# observed `v4_ipv6_cidr_block`; for IPAM also capture `v4_ipv6_ipam_pool_id`
# and `v4_ipv6_netmask_length` when present from
# `terraform state show module.vpc.aws_vpc.main[0]`. A v4 pool-only allocation
# must be represented in v5 by its observed CIDR and pool ID. Build
# `local.v4_ipv6_import_id` exactly as documented in the upgrade guide. These
# blocks remain comments here because Terraform forbids import blocks when this
# example is loaded as a child module by native plan tests. `removed.from`
# addresses must not contain module or resource instance keys.
#
# removed {
#   from = module.vpc.module.flow_logs.aws_cloudwatch_log_group.main
#
#   lifecycle {
#     destroy = false
#   }
# }
#
# removed {
#   from = module.vpc.module.flow_logs.aws_iam_role_policy.flow_logs
#
#   lifecycle {
#     destroy = false
#   }
# }
#
# import {
#   to = module.vpc.aws_cloudwatch_log_group.flow_logs["default"]
#   id = var.v4_flow_log_group_name
# }
#
# # v4 stores this association inside aws_vpc.main; no moved block can target it.
# # The v5 module ignores the legacy embedded IPv6 fields on aws_vpc.main so the
# # provider cannot disassociate the live prefix while this import takes ownership.
# # Reject the migration plan if aws_vpc.main shows any IPv6 argument update.
# import {
#   to = module.vpc.aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"]
#   id = local.v4_ipv6_import_id
# }
