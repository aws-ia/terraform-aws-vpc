mock_provider "aws" {
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
      id                        = "vpc-mock"
      arn                       = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block                = "10.42.0.0/16"
      default_security_group_id = "sg-default"
      default_network_acl_id    = "acl-default"
      default_route_table_id    = "rtb-default"
      main_route_table_id       = "rtb-default"
    }
  }

  mock_resource "aws_vpc_ipv6_cidr_block_association" {
    defaults = {
      id              = "vpc-cidr-assoc-0123456789abcdef0"
      ipv6_cidr_block = "2001:db8:4200::/56"
    }
  }
}

run "seed_representative_v4_state" {
  command   = apply
  state_key = "representative-moved-state"

  module {
    source = "./tests/fixtures/moved-v4"
  }

  assert {
    condition = (
      output.subnet_id != null && output.route_table_id != null && output.association_id != null &&
      output.vpc_assign_generated_ipv6_cidr_block
    )
    error_message = "The mocked v4 fixture must seed subnet, route-table, association, and embedded IPv6 VPC state."
  }
}

run "plan_representative_v5_moves" {
  command   = plan
  state_key = "representative-moved-state"

  module {
    source = "./tests/fixtures/moved-v5"
  }

  assert {
    condition     = output.subnet_keys == ["public/us-east-1a"]
    error_message = "The moved subnet must use the unified v5 group/AZ key."
  }

  assert {
    condition     = output.subnet_id == run.seed_representative_v4_state.subnet_id
    error_message = "The subnet ID must remain known and unchanged after the state move."
  }

  assert {
    condition = (
      output.route_table_id == run.seed_representative_v4_state.route_table_id &&
      output.association_id == run.seed_representative_v4_state.association_id
    )
    error_message = "Route-table and association IDs must remain known and unchanged after state moves."
  }
}

run "validate_root_migration_handoff_syntax" {
  command = plan

  module {
    source = "./tests/fixtures/migration-root-handoff"
  }

  assert {
    condition     = output.v4_ipv6_import_id == "vpc-cidr-assoc-0123456789abcdef0"
    error_message = "Amazon-provided IPv6 imports must use the association ID alone."
  }
}

run "validate_ipv6_ipam_cidr_import_id" {
  command = plan

  module {
    source = "./tests/fixtures/migration-root-handoff"
  }

  variables {
    v4_ipv6_ipam_pool_id = "ipam-pool-0123456789abcdef0"
  }

  assert {
    condition     = output.v4_ipv6_import_id == "vpc-cidr-assoc-0123456789abcdef0,ipam-pool-0123456789abcdef0"
    error_message = "IPv6 IPAM imports with an explicit CIDR must preserve association and pool IDs."
  }
}

run "validate_ipv6_ipam_netmask_import_id" {
  command = plan

  module {
    source = "./tests/fixtures/migration-root-handoff"
  }

  variables {
    v4_ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    v4_ipv6_netmask_length = 56
  }

  assert {
    condition     = output.v4_ipv6_import_id == "vpc-cidr-assoc-0123456789abcdef0,ipam-pool-0123456789abcdef0,56"
    error_message = "IPv6 IPAM netmask imports must preserve association ID, pool ID, and ForceNew netmask length."
  }
}

run "plan_full_migration_example" {
  command   = plan
  state_key = "full-migration-syntax"

  module {
    source = "./examples/migration-from-v4"
  }

  assert {
    condition     = keys(output.v4_private_subnet_attributes_by_az) == ["app/us-east-1a", "app/us-east-1b"]
    error_message = "The complete migration example, including all 63 moved blocks, must plan with v4-compatible private keys."
  }

  assert {
    condition = (
      output.default_resource_management.security_group_count == 0 &&
      output.default_resource_management.network_acl_count == 0 &&
      output.default_resource_management.route_table_count == 0
    )
    error_message = "Default ID observation must not adopt lifecycle ownership during migration."
  }

  assert {
    condition = output.v4_name_compatibility == {
      public_subnet      = "public-us-east-1a"
      app_route_table    = "app-us-east-1a"
      nat_eip            = "nat-public-us-east-1a"
      nat_gateway        = "nat-public-us-east-1a"
      internet_gateway   = "migration-example-igw"
      egress_only_igw    = "migration-example"
      flow_log           = "migration-example"
      log_group_has_name = false
    }
    error_message = "The migration example must reproduce all v4 Name tags exactly, including the Flow Log Name and absent log-group Name."
  }
}

run "plan_ipv6_ipam_pool_default_handoff" {
  command = plan

  variables {
    vpc = { name = "ipv6-pool-default-handoff" }
    addressing = {
      primary = { cidr_block = "10.42.0.0/16" }
      secondary = {
        v4-ipv6 = {
          ipv6 = {
            ipam_pool_id = "ipam-pool-0123456789abcdef0"
            cidr_block   = "2001:db8:4200::/56"
          }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
  }

  assert {
    condition = (
      aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"].ipv6_ipam_pool_id == "ipam-pool-0123456789abcdef0" &&
      aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"].ipv6_cidr_block == "2001:db8:4200::/56" &&
      aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"].ipv6_netmask_length == null
    )
    error_message = "A v4 pool-default IPv6 allocation must hand off through its observed CIDR and pool without inventing a netmask."
  }
}
