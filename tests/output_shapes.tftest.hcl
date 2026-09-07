mock_provider "aws" {
  override_during = plan
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = {
      id              = "subnet-mock"
      arn             = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
      ipv6_cidr_block = ""
    }
  }

  mock_resource "aws_route_table" {
    defaults = { id = "rtb-mock" }
  }

  mock_resource "aws_internet_gateway" {
    defaults = { id = "igw-mock" }
  }

  mock_resource "aws_nat_gateway" {
    defaults = {
      id            = "nat-mock"
      allocation_id = "eipalloc-mock"
      private_ip    = "10.0.0.10"
      public_ip     = "198.51.100.10"
    }
  }

  mock_resource "aws_ec2_transit_gateway_vpc_attachment" {
    defaults = { id = "tgw-attach-mock" }
  }

  mock_resource "aws_networkmanager_vpc_attachment" {
    defaults = { id = "cwan-attach-mock" }
  }

  mock_resource "aws_flow_log" {
    defaults = { id = "fl-mock" }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn       = "arn:aws:iam::123456789012:role/shape-test-flow-logs"
      id        = "shape-test-flow-logs"
      name      = "shape-test-flow-logs"
      unique_id = "mock-role-unique-id"
    }
  }

  mock_resource "aws_vpclattice_service_network_vpc_association" {
    defaults = { id = "snva-mock" }
  }
}

run "tier_1_and_tier_2_shapes" {
  command = plan

  variables {
    vpc                = { name = "shape-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }

    subnets = {
      public = {
        role = "public"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24", "us-east-1b" = "10.0.1.0/24" } }
      }
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.0.10.0/24", "us-east-1b" = "10.0.11.0/24" } }
        routing = { nat_gateway = true }
      }
      transit_gateway = {
        role = "transit_gateway"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.240.0/28", "us-east-1b" = "10.0.240.16/28" } }
        transit_gateway_options = {
          id = "tgw-0123456789abcdef0"
        }
      }
      core_network = {
        role = "core_network"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.241.0/28", "us-east-1b" = "10.0.241.16/28" } }
        core_network_options = {
          id  = "cnet-0123456789abcdef0"
          arn = "arn:aws:networkmanager::123456789012:core-network/cnet-0123456789abcdef0"
        }
      }
    }

    nat_gateway = {
      mode         = "single_az"
      az           = "us-east-1a"
      subnet_group = "public"
      eip = {
        mode = "existing"
        allocation_ids = {
          us-east-1a = "eipalloc-mock"
        }
      }
    }

    flow_logs = {
      default = {
        destination_type   = "cloudwatch"
        create_destination = false
        destination_arn    = "arn:aws:logs:us-east-1:123456789012:log-group:shape-test"
      }
    }

    vpc_lattice = {
      enabled                    = true
      service_network_identifier = "sn-0123456789abcdef0"
    }
  }

  assert {
    condition = (
      output.vpc_id == "vpc-mock" && output.vpc_arn == "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock" &&
      output.vpc_cidr_block == "10.0.0.0/16" && output.azs == tolist(["us-east-1a", "us-east-1b"])
    )
    error_message = "Tier 1 VPC identity and AZ shapes changed."
  }

  assert {
    condition = (
      toset(keys(output.subnet_ids_by_group_by_az)) == toset(["app", "core_network", "public", "transit_gateway"]) &&
      alltrue([for group in keys(output.subnet_ids_by_group_by_az) : toset(keys(output.subnet_ids_by_group_by_az[group])) == toset(["us-east-1a", "us-east-1b"])]) &&
      toset(keys(output.subnet_ids_by_semantic_role)) == toset(["core_network", "isolated", "private", "public", "transit_gateway"]) &&
      output.subnet_ids_by_group_by_az.app["us-east-1a"] == "subnet-mock"
    )
    error_message = "Tier 1 subnet keys, nesting, semantic roles, or direct ID access changed."
  }

  assert {
    condition = (
      toset(keys(output.route_table_ids_by_group_by_az)) == toset(["app", "core_network", "public", "transit_gateway"]) &&
      alltrue([for group in keys(output.route_table_ids_by_group_by_az) : toset(keys(output.route_table_ids_by_group_by_az[group])) == toset(["us-east-1a", "us-east-1b"])]) &&
      output.route_table_ids_by_group_by_az.public["us-east-1b"] == "rtb-mock" &&
      length(output.route_table_ids_by_semantic_role_by_az.private["us-east-1a"]) == 1 && output.route_table_ids_by_semantic_role_by_az.private["us-east-1a"][0] == "rtb-mock"
    )
    error_message = "Tier 1 route-table keys, nesting, or direct ID access changed."
  }

  assert {
    condition = (
      toset(keys(output.nat_gateway_ids)) == toset(["us-east-1a"]) && output.nat_gateway_ids["us-east-1a"] == "nat-mock" &&
      output.internet_gateway_id == "igw-mock" &&
      output.transit_gateway_attachment_id == "tgw-attach-mock" &&
      output.core_network_attachment_id == "cwan-attach-mock" &&
      toset(keys(output.flow_log_ids)) == toset(["default"]) && output.flow_log_ids.default == "fl-mock" &&
      toset(keys(output.resources.flow_log_roles.default)) == toset(["arn", "id", "name", "unique_id"]) &&
      output.resources.flow_log_roles.default.arn == "arn:aws:iam::123456789012:role/shape-test-flow-logs" &&
      output.vpc_lattice_service_network_association_id == "snva-mock"
    )
    error_message = "Tier 1 gateway, attachment, Flow Log, or Lattice handles changed."
  }

  assert {
    condition = (
      toset(keys(output.private_subnet_attributes_by_az)) == toset(["app/us-east-1a", "app/us-east-1b"]) &&
      toset(keys(output.public_subnet_attributes_by_az)) == toset(["us-east-1a", "us-east-1b"]) &&
      toset(keys(output.tgw_subnet_attributes_by_az)) == toset(["us-east-1a", "us-east-1b"]) &&
      toset(keys(output.core_network_subnet_attributes_by_az)) == toset(["us-east-1a", "us-east-1b"]) &&
      output.private_subnet_attributes_by_az["app/us-east-1a"].id == "subnet-mock" &&
      output.public_subnet_attributes_by_az["us-east-1a"].id == "subnet-mock" &&
      output.tgw_subnet_attributes_by_az["us-east-1a"].id == "subnet-mock" &&
      output.core_network_subnet_attributes_by_az["us-east-1a"].id == "subnet-mock"
    )
    error_message = "Tier 2 subnet alias keys, nesting, or direct .id access changed."
  }

  assert {
    condition = (
      toset(keys(output.rt_attributes_by_type_by_az)) == toset(["core_network", "private", "public", "transit_gateway"]) &&
      toset(keys(output.rt_attributes_by_type_by_az.private)) == toset(["app/us-east-1a", "app/us-east-1b"]) &&
      toset(keys(output.rt_attributes_by_type_by_az.public)) == toset(["us-east-1a", "us-east-1b"]) &&
      toset(keys(output.rt_attributes_by_type_by_az.transit_gateway)) == toset(["us-east-1a", "us-east-1b"]) &&
      toset(keys(output.rt_attributes_by_type_by_az.core_network)) == toset(["us-east-1a", "us-east-1b"]) &&
      output.rt_attributes_by_type_by_az.private["app/us-east-1a"].id == "rtb-mock" &&
      output.rt_attributes_by_type_by_az.public["us-east-1a"].id == "rtb-mock" &&
      output.rt_attributes_by_type_by_az.transit_gateway["us-east-1a"].id == "rtb-mock" &&
      output.rt_attributes_by_type_by_az.core_network["us-east-1a"].id == "rtb-mock"
    )
    error_message = "Tier 2 route-table aliases must retain all four outer groups and direct .id access."
  }

  assert {
    condition = (
      toset(keys(output.nat_gateway_attributes_by_az)) == toset(["us-east-1a"]) &&
      output.nat_gateway_attributes_by_az["us-east-1a"].id == "nat-mock" &&
      toset(keys(output.natgw_id_per_az)) == toset(["us-east-1a", "us-east-1b"]) &&
      output.natgw_id_per_az["us-east-1a"].id == "nat-mock" &&
      output.natgw_id_per_az["us-east-1b"].id == "nat-mock"
    )
    error_message = "Tier 2 single_az NAT aliases must retain one object and duplicate its ID across AZs."
  }

  assert {
    condition = (
      output.vpc_attributes.id == "vpc-mock" &&
      output.internet_gateway.id == "igw-mock" &&
      output.transit_gateway_attachment_id == "tgw-attach-mock" &&
      output.core_network_attachment.id == "cwan-attach-mock" &&
      output.flow_log_attributes.id == "fl-mock" &&
      output.vpc_lattice_service_network_association.id == "snva-mock"
    )
    error_message = "Tier 2 singleton aliases must retain full objects with direct .id access."
  }
}

run "absent_optional_resources" {
  command = plan

  variables {
    vpc                = { name = "absence-test" }
    addressing         = { primary = { cidr_block = "10.1.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      data = {
        role = "isolated"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.1.0.0/24" } }
      }
    }
  }

  assert {
    condition = (
      length(output.nat_gateway_ids) == 0 && output.internet_gateway_id == null && output.egress_only_igw_id == null &&
      output.transit_gateway_attachment_id == null && output.core_network_attachment_id == null &&
      length(output.flow_log_ids) == 0 && output.vpc_lattice_service_network_association_id == null &&
      alltrue([for cidr in values(output.subnet_ipv6_cidrs_by_group_by_az.data) : cidr == null])
    )
    error_message = "Tier 1 optional handles must be empty or null when resources are absent."
  }

  assert {
    condition = (
      length(output.public_subnet_attributes_by_az) == 0 && length(output.tgw_subnet_attributes_by_az) == 0 &&
      length(output.core_network_subnet_attributes_by_az) == 0 && length(output.nat_gateway_attributes_by_az) == 0 &&
      length(output.natgw_id_per_az) == 0 && output.internet_gateway == null &&
      output.egress_only_internet_gateway == null && output.core_network_attachment == null &&
      output.flow_log_attributes == null && output.vpc_lattice_service_network_association == null
    )
    error_message = "Tier 2 aliases must be empty or null when optional resources are absent."
  }

  assert {
    condition = (
      length(output.resources.internet_gateway) == 0 &&
      length(output.resources.egress_only_internet_gateway) == 0 &&
      length(output.resources.nat_gateways) == 0 &&
      length(output.resources.transit_gateway_attachments) == 0 &&
      length(output.resources.core_network_attachments) == 0 &&
      length(output.resources.flow_logs) == 0 &&
      length(output.resources.vpc_lattice_associations) == 0
    )
    error_message = "Tier 3 resource collections must be empty when optional resources are absent."
  }
}
