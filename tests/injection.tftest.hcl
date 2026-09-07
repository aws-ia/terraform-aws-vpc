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

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-existing-documentation"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-existing-documentation"
      cidr_block = "10.0.0.0/16"
      ipv6_cidr_block_associations = [
        {
          association_id  = "vpc-cidr-assoc-a"
          ipv6_cidr_block = "2001:db8:100::/56"
          state           = "associated"
        },
        {
          association_id  = "vpc-cidr-assoc-b"
          ipv6_cidr_block = "2001:db8:200::/56"
          state           = "associated"
        }
      ]
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      id              = "subnet-existing-mock"
      arn             = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-existing-mock"
      cidr_block      = "10.0.0.0/24"
      ipv6_cidr_block = "2001:db8:4200::/64"
    }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id              = "vpc-mock"
      arn             = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block      = "10.0.0.0/16"
      ipv6_cidr_block = "2001:db8:4200::/56"
    }
  }

  mock_resource "aws_route_table" {
    defaults = { id = "rtb-mock" }
  }
}

run "inject_all_remaining_boundaries" {
  command = plan

  variables {
    vpc = {
      name        = "boundary-inject-test"
      eigw_create = false
      eigw_id     = "eigw-0123456789abcdef0"
    }
    addressing = {
      primary   = { cidr_block = "10.0.0.0/16" }
      secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role         = "private"
        create       = false
        existing_ids = { us-east-1a = "subnet-01111111111111111" }
        ipv4         = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
        ipv6         = { secondary_cidr_key = "ipv6", cidrs_by_az = { "us-east-1a" = "2001:db8:4200::/64" } }
        routing      = { egress_only_igw = true }
      }
      tgw = {
        role         = "transit_gateway"
        create       = false
        existing_ids = { us-east-1a = "subnet-02222222222222222" }
        ipv4         = { cidrs_by_az = { "us-east-1a" = "10.0.1.0/28" } }
        transit_gateway_options = {
          id            = "tgw-0123456789abcdef0"
          create        = false
          attachment_id = "tgw-attach-0123456789abcdef0"
        }
      }
      cwan = {
        role         = "core_network"
        create       = false
        existing_ids = { us-east-1a = "subnet-03333333333333333" }
        ipv4         = { cidrs_by_az = { "us-east-1a" = "10.0.2.0/28" } }
        core_network_options = {
          id                 = "cnet-0123456789abcdef0"
          arn                = "arn:aws:networkmanager::123456789012:core-network/cnet-0123456789abcdef0"
          create             = false
          attachment_id      = "attachment-0123456789abcdef0"
          require_acceptance = true
          accept_attachment  = true
          create_accepter    = false
          accepter_id        = "attachment-0123456789abcdef0"
        }
      }
    }
    flow_logs = {
      audit = {
        create = false
        id     = "fl-0123456789abcdef0"
      }
    }
    vpc_lattice = {
      enabled = true
      create  = false
      id      = "snva-0123456789abcdef0"
    }
  }

  assert {
    condition = (
      length(aws_egress_only_internet_gateway.main) == 0 &&
      output.egress_only_igw_id == "eigw-0123456789abcdef0" &&
      length(aws_subnet.main) == 0 &&
      toset(keys(output.subnet_ids_by_group_by_az)) == toset(["app", "cwan", "tgw"])
    )
    error_message = "EIGW and subnet injection must omit owned resources while preserving stable handles."
  }

  assert {
    condition = (
      length(aws_ec2_transit_gateway_vpc_attachment.this) == 0 &&
      output.transit_gateway_attachment_id == "tgw-attach-0123456789abcdef0" &&
      length(aws_networkmanager_vpc_attachment.this) == 0 &&
      length(aws_networkmanager_attachment_accepter.this) == 0 &&
      output.core_network_attachment_id == "attachment-0123456789abcdef0" &&
      output.core_network_attachment_accepter_id == "attachment-0123456789abcdef0"
    )
    error_message = "TGW/Cloud WAN attachment and accepter injection must omit owned resources and return injected IDs."
  }

  assert {
    condition = (
      length(aws_flow_log.this) == 0 && output.flow_log_ids.audit == "fl-0123456789abcdef0" &&
      length(aws_vpclattice_service_network_vpc_association.this) == 0 &&
      output.vpc_lattice_service_network_association_id == "snva-0123456789abcdef0"
    )
    error_message = "Flow Log and Lattice injection must omit owned resources and return injected IDs."
  }
}

run "reject_missing_injected_eigw" {
  command = plan

  variables {
    vpc = {
      name        = "negative-test"
      eigw_create = false
    }
    addressing = {
      primary   = { cidr_block = "10.0.0.0/16" }
      secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
        ipv6    = { secondary_cidr_key = "ipv6", auto_assign = true }
        routing = { egress_only_igw = true }
      }
    }
  }

  expect_failures = [terraform_data.eigw_injection_validation[0]]
}

run "reject_incomplete_injected_subnet_ids" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role         = "private"
        create       = false
        existing_ids = { us-east-1a = "subnet-01111111111111111" }
        ipv4         = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24", "us-east-1b" = "10.0.1.0/24" } }
      }
    }
  }

  expect_failures = [terraform_data.subnet_existing_ids_validation["app"]]
}

run "reject_missing_injected_attachment_id" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      tgw = {
        role = "transit_gateway"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/28" } }
        transit_gateway_options = {
          id     = "tgw-0123456789abcdef0"
          create = false
        }
      }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_missing_injected_flow_log_id" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    flow_logs = {
      audit = { create = false }
    }
  }

  expect_failures = [var.flow_logs]
}

run "reject_missing_injected_lattice_id" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    vpc_lattice = {
      enabled = true
      create  = false
    }
  }

  expect_failures = [var.vpc_lattice]
}

run "injected_ipv6_association_selector_is_stable" {
  command = plan

  variables {
    vpc                = { name = "selected-ipv6", create = false, id = "vpc-existing-documentation" }
    addressing         = { primary = {}, secondary = { ipv6 = { ipv6 = { create = false, association_id = "vpc-cidr-assoc-b" } } } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.0.10.0/24" } }
        ipv6 = { secondary_cidr_key = "ipv6", auto_assign = true }
      }
    }
  }

  assert {
    condition = (
      output.vpc_ipv6_cidr_block == "2001:db8:200::/56" &&
      aws_subnet.main["app/us-east-1a"].ipv6_cidr_block == "2001:db8:200::/64"
    )
    error_message = "Injected IPv6 calculation must use the caller-selected association instead of lexicographic order."
  }
}

run "reject_unknown_injected_ipv6_association" {
  command = plan

  variables {
    vpc                = { name = "unknown-ipv6", create = false, id = "vpc-existing-documentation" }
    addressing         = { primary = {}, secondary = { ipv6 = { ipv6 = { create = false, association_id = "vpc-cidr-assoc-missing" } } } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
  }

  expect_failures = [terraform_data.injected_ipv6_association_validation["ipv6"]]
}
