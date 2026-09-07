terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29"
    }
  }
}

resource "terraform_data" "vpc_id" {
  input = "vpc-upstream"
}

resource "terraform_data" "igw_id" {
  input = "igw-upstream"
}

resource "terraform_data" "route_table_id" {
  input = "rtb-upstream"
}

resource "terraform_data" "log_destination" {
  input = "arn:aws:logs:us-east-1:123456789012:log-group:computed"
}

resource "terraform_data" "log_role" {
  input = "arn:aws:iam::123456789012:role/computed-flow-logs"
}

resource "terraform_data" "service_network" {
  input = "sn-computed"
}

resource "terraform_data" "ipv6_pool" {
  input = "ipam-pool-computed"
}

resource "terraform_data" "ipv6_association_id" {
  input = "vpc-cidr-assoc-computed"
}

resource "terraform_data" "ipv6_selector" {
  input = "ipv6"
}

resource "terraform_data" "cwan_attachment_id" {
  input = "attachment-computed"
}

resource "terraform_data" "cwan_accepter_id" {
  input = "accepter-computed"
}

resource "terraform_data" "route_target_id" {
  input = "pcx-computed"
}

module "vpc" {
  source = "../../.."

  vpc = {
    name       = "computed-inputs"
    create     = false
    id         = terraform_data.vpc_id.output
    igw_create = false
    igw_id     = terraform_data.igw_id.output
  }

  addressing         = { primary = {}, secondary = { ipv6 = { ipv6 = { create = false, association_id = terraform_data.ipv6_association_id.output } } } }
  availability_zones = { names = ["us-east-1a"] }

  subnets = {
    public = {
      role               = "public"
      manage_route_table = false
      route_table_key    = "external-public"
      route_table_id     = terraform_data.route_table_id.output
      ipv4               = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
      routing            = { internet_gateway = true }
      routes = {
        computed-peer = {
          destination = { type = "ipv4_cidr", value = "10.210.0.0/16" }
          target      = { type = "vpc_peering", id = terraform_data.route_target_id.output }
        }
      }
    }

    ipam = {
      role = "private"
      ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.1.0/24" } }
      ipv6 = {
        secondary_cidr_key = terraform_data.ipv6_selector.output
        ipam_pool_id       = terraform_data.ipv6_pool.output
        netmask_length     = 64
        auto_assign        = true
      }
      routing = { core_network = ["10.200.0.0/16"] }
    }

    cwan = {
      role = "core_network"
      ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.2.0/28" } }
      core_network_options = {
        id                 = "cnet-0123456789abcdef0"
        arn                = "arn:aws:networkmanager::123456789012:core-network/cnet-0123456789abcdef0"
        create             = false
        attachment_id      = terraform_data.cwan_attachment_id.output
        require_acceptance = true
        accept_attachment  = true
        create_accepter    = false
        accepter_id        = terraform_data.cwan_accepter_id.output
      }
    }
  }

  flow_logs = {
    audit = {
      destination_type   = "cloudwatch"
      create_destination = false
      destination_arn    = terraform_data.log_destination.output
      create_iam_role    = false
      iam_role_arn       = terraform_data.log_role.output
    }
  }

  vpc_lattice = {
    enabled                    = true
    service_network_identifier = terraform_data.service_network.output
  }
}

output "composition_shape" {
  value = {
    subnet_groups        = keys(module.vpc.subnet_ids_by_group)
    route_table_groups   = keys(module.vpc.route_table_ids_by_group)
    flow_log_keys        = keys(module.vpc.flow_log_ids)
    created_vpcs         = length(module.vpc.resources.vpc.created)
    created_igws         = length(module.vpc.resources.internet_gateway)
    created_route_tables = length(module.vpc.resources.route_tables)
    lattice_associations = length(module.vpc.resources.vpc_lattice_associations)
    cwan_routes          = length(module.vpc.resources.routes.cwan)
    cwan_readiness_keys  = keys(module.vpc.resources.core_network_readiness)
    custom_route_keys    = keys(module.vpc.resources.routes.custom)
  }
}
