mock_provider "aws" {
  override_during = plan

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id              = "vpc-mock"
      arn             = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block      = "10.96.0.0/16"
      ipv6_cidr_block = "2001:db8:9600::/56"
    }
  }

  mock_resource "aws_subnet" {
    defaults = { id = "subnet-mock" }
  }

  mock_resource "aws_vpc_endpoint" {
    defaults = { id = "vpce-s3" }
  }
}

run "shared_physical_route_table_is_materialized_once" {
  command = plan

  variables {
    vpc                = { name = "shared-route-table" }
    addressing         = { primary = { cidr_block = "10.96.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      public_a = {
        role               = "public"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.96.0.0/24", us-east-1b = "10.96.1.0/24" } }
        manage_route_table = false
        route_table_key    = "shared-public"
        route_table_id     = "rtb-shared"
        routing            = { s3_gateway_endpoint = true }
      }
      public_b = {
        role               = "public"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.96.2.0/24", us-east-1b = "10.96.3.0/24" } }
        manage_route_table = false
        route_table_key    = "shared-public"
        route_table_id     = "rtb-shared"
        routing            = { s3_gateway_endpoint = true }
      }
    }
    gateway_endpoints = { s3 = { service = "s3" } }
  }

  assert {
    condition = (
      length(aws_route_table_association.main) == 4 &&
      toset(keys(aws_route.igw_ipv4)) == toset(["injected/shared-public/igw"]) &&
      toset(keys(aws_vpc_endpoint_route_table_association.gateway)) == toset(["injected/shared-public/gateway-endpoint/s3"])
    )
    error_message = "Two groups sharing one physical route_table_key must retain four subnet associations but create each physical route/endpoint association once."
  }
}

run "reject_route_table_key_with_different_ids" {
  command = plan

  variables {
    vpc                = { name = "invalid-route-table-identity" }
    addressing         = { primary = { cidr_block = "10.97.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.97.0.0/24" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-one"
      }
      data = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.97.1.0/24" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-two"
      }
    }
  }

  expect_failures = [terraform_data.injected_route_table_identity_validation[0]]
}

run "reject_isolated_sharing_public_route_table" {
  command = plan

  variables {
    vpc                = { name = "isolated-shared-table" }
    addressing         = { primary = { cidr_block = "10.98.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      public = {
        role               = "public"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.98.0.0/24" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-shared"
      }
      data = {
        role                                     = "isolated"
        ipv4                                     = { cidrs_by_az = { us-east-1a = "10.98.1.0/24" } }
        manage_route_table                       = false
        route_table_key                          = "shared"
        route_table_id                           = "rtb-shared"
        isolated_accepts_uninspected_route_table = true
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_igw_and_nat_same_destination" {
  command = plan

  variables {
    vpc                = { name = "igw-nat-collision" }
    addressing         = { primary = { cidr_block = "10.99.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { us-east-1a = "10.99.0.0/24" } }
        routing = { internet_gateway = true, nat_gateway = true }
      }
    }
    nat_gateway = {
      mode         = "single_az"
      az           = "us-east-1a"
      create       = false
      existing_ids = { us-east-1a = "nat-documentation" }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_ipv6_igw_and_eigw_same_destination" {
  command = plan

  variables {
    vpc                = { name = "igw-eigw-collision" }
    addressing         = { primary = { cidr_block = "10.100.0.0/16" }, secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { us-east-1a = "10.100.0.0/24" } }
        ipv6    = { secondary_cidr_key = "ipv6", auto_assign = true }
        routing = { internet_gateway = true, egress_only_igw = true }
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_tgw_and_cwan_same_destination" {
  command = plan

  variables {
    vpc                = { name = "transit-collision" }
    addressing         = { primary = { cidr_block = "10.101.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { us-east-1a = "10.101.0.0/24" } }
        routing = { transit_gateway = ["10.0.0.0/8"], core_network = ["10.0.0.0/8"] }
      }
      tgw = {
        role                    = "transit_gateway"
        ipv4                    = { cidrs_by_az = { us-east-1a = "10.101.1.0/28" } }
        transit_gateway_options = { id = "tgw-documentation", create = false, attachment_id = "tgw-attach-documentation" }
      }
      cwan = {
        role = "core_network"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.101.2.0/28" } }
        core_network_options = {
          id            = "cnet-0123456789abcdef0"
          arn           = "arn:aws:networkmanager::123456789012:core-network/cnet-0123456789abcdef0"
          create        = false
          attachment_id = "attachment-documentation"
        }
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_isolated_sharing_generic_ipv4_route" {
  command = plan

  variables {
    vpc                = { name = "isolated-generic-ipv4" }
    addressing         = { primary = { cidr_block = "10.102.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.102.0.0/24" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-shared"
        routes = {
          egress = {
            destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
            target      = { type = "vpc_endpoint", id = "vpce-documentation" }
          }
        }
      }
      data = {
        role                                     = "isolated"
        ipv4                                     = { cidrs_by_az = { us-east-1a = "10.102.1.0/24" } }
        manage_route_table                       = false
        route_table_key                          = "shared"
        route_table_id                           = "rtb-shared"
        isolated_accepts_uninspected_route_table = true
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_isolated_sharing_generic_ipv6_route" {
  command = plan

  variables {
    vpc                = { name = "isolated-generic-ipv6" }
    addressing         = { primary = { cidr_block = "10.103.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.103.0.0/24" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-shared"
        routes = {
          partner-v6 = {
            destination = { type = "ipv6_cidr", value = "2001:db8:100::/48" }
            target      = { type = "vpc_peering", id = "pcx-documentation" }
          }
        }
      }
      data = {
        role                                     = "isolated"
        ipv4                                     = { cidrs_by_az = { us-east-1a = "10.103.1.0/24" } }
        manage_route_table                       = false
        route_table_key                          = "shared"
        route_table_id                           = "rtb-shared"
        isolated_accepts_uninspected_route_table = true
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_isolated_sharing_generic_prefix_list_route" {
  command = plan

  variables {
    vpc                = { name = "isolated-generic-prefix" }
    addressing         = { primary = { cidr_block = "10.104.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.104.0.0/24" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-shared"
        routes = {
          partner-prefix = {
            destination = { type = "prefix_list", value = "pl-0123456789abcdef0" }
            target      = { type = "vpc_peering", id = "pcx-documentation" }
          }
        }
      }
      data = {
        role                                     = "isolated"
        ipv4                                     = { cidrs_by_az = { us-east-1a = "10.104.1.0/24" } }
        manage_route_table                       = false
        route_table_key                          = "shared"
        route_table_id                           = "rtb-shared"
        isolated_accepts_uninspected_route_table = true
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_clean_injected_isolated_route_table_without_opt_in" {
  command = plan

  variables {
    vpc                = { name = "isolated-unmanaged-clean" }
    addressing         = { primary = { cidr_block = "10.105.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      data = {
        role               = "isolated"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.105.0.0/24" } }
        manage_route_table = false
        route_table_key    = "isolated"
        route_table_id     = "rtb-clean"
      }
    }
  }

  expect_failures = [terraform_data.isolated_injected_route_table_validation]
}

run "reject_gwlb_endpoint_default_route_without_opt_in" {
  command = plan

  # This external table represents the adversarial reproducer containing
  # 0.0.0.0/0 -> vpce-gwlb-0123456789abcdef0. Route contents are deliberately
  # not inspected: every unmanaged isolated table fails closed.
  variables {
    vpc                = { name = "isolated-unmanaged-gwlb-default" }
    addressing         = { primary = { cidr_block = "10.106.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      data = {
        role               = "isolated"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.106.0.0/24" } }
        manage_route_table = false
        route_table_key    = "isolated"
        route_table_id     = "rtb-gwlb-default"
      }
    }
  }

  expect_failures = [terraform_data.isolated_injected_route_table_validation]
}

run "allow_explicit_uninspected_isolated_route_table" {
  command = plan

  variables {
    vpc                = { name = "isolated-uninspected-opt-in" }
    addressing         = { primary = { cidr_block = "10.107.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      data = {
        role                                     = "isolated"
        ipv4                                     = { cidrs_by_az = { us-east-1a = "10.107.0.0/24" } }
        manage_route_table                       = false
        route_table_key                          = "isolated"
        route_table_id                           = "rtb-uninspected"
        isolated_accepts_uninspected_route_table = true
      }
    }
  }

  assert {
    condition     = length(aws_route_table_association.main) == 1
    error_message = "The explicit dangerous opt-in must preserve the injected route-table association."
  }
}
