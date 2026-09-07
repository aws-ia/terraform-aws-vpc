mock_provider "aws" {
  mock_resource "aws_vpc" {
    defaults = {
      id                               = "vpc-mock"
      arn                              = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block                       = "10.44.0.0/16"
      ipv6_association_id              = "vpc-cidr-assoc-0123456789abcdef0"
      ipv6_cidr_block                  = "2001:db8:4400::/56"
      assign_generated_ipv6_cidr_block = true
      default_security_group_id        = "sg-default"
      default_network_acl_id           = "acl-default"
      default_route_table_id           = "rtb-default"
      main_route_table_id              = "rtb-default"
    }
  }

  mock_resource "aws_vpc_ipv6_cidr_block_association" {
    defaults = {
      id              = "vpc-cidr-assoc-0123456789abcdef0"
      ipv6_cidr_block = "2001:db8:4400::/56"
    }
  }
}

run "seed_v4_embedded_ipv6_state" {
  command   = apply
  state_key = "production-ipv6-handoff"

  module {
    source = "../migration-v4-ipv6"
  }

  assert {
    condition = (
      output.vpc_id == "vpc-mock" &&
      output.ipv6_association_id == "vpc-cidr-assoc-0123456789abcdef0" &&
      output.assign_generated_ipv6_cidr_block
    )
    error_message = "The v4 seed must retain its embedded IPv6 association before handoff."
  }
}

run "plan_production_module_handoff" {
  command   = plan
  state_key = "production-ipv6-handoff"

  # Terraform test mock providers cannot execute importers. This override supplies
  # only the imported read values; test-migration-handoff.sh asserts that the plan
  # action is import (never create), while test-ipv6-import-shape.sh exercises the
  # real AWS provider 6.59 importer.
  override_resource {
    target          = module.vpc.aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"]
    override_during = plan
    values = {
      id              = "vpc-cidr-assoc-0123456789abcdef0"
      ipv6_cidr_block = "2001:db8:4400::/56"
    }
  }

  assert {
    condition = (
      output.vpc_id == run.seed_v4_embedded_ipv6_state.vpc_id &&
      output.vpc_assign_generated_ipv6_cidr_block == run.seed_v4_embedded_ipv6_state.assign_generated_ipv6_cidr_block &&
      output.ipv6_association_id == run.seed_v4_embedded_ipv6_state.ipv6_association_id
    )
    error_message = "Production lifecycle and standalone import must preserve the VPC and association identities without clearing embedded IPv6 state."
  }
}
