mock_provider "aws" {
  override_during = plan

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.130.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = { id = "subnet-mock" }
  }

  mock_resource "aws_route_table" {
    defaults = { id = "rtb-mock" }
  }

  mock_resource "aws_vpc_endpoint" {
    defaults = { id = "vpce-s3" }
  }
}

run "top_level_static_target_expands_by_az" {
  command = plan

  variables {
    vpc                = { name = "top-level-static" }
    addressing         = { primary = { cidr_block = "10.130.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.130.0.0/24", us-east-1b = "10.130.1.0/24" } }
      }
    }
    routes = {
      services = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
        target      = { type = "vpc_peering", id = "pcx-documentation" }
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_route.top_level)) == toset(["services/us-east-1a", "services/us-east-1b"]) &&
      alltrue([for route in values(aws_route.top_level) : route.vpc_peering_connection_id == "pcx-documentation"])
    )
    error_message = "A static top-level target must expand with stable <route-key>/<az> addresses and one target value."
  }
}

run "top_level_zonal_targets_cover_all_destination_types" {
  command = plan

  variables {
    vpc                = { name = "top-level-zonal" }
    addressing         = { primary = { cidr_block = "10.131.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.131.0.0/24", us-east-1b = "10.131.1.0/24" } }
      }
    }
    routes = {
      inspect-v4 = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
        target = {
          type      = "vpc_endpoint"
          ids_by_az = { us-east-1a = "vpce-a", us-east-1b = "vpce-b" }
        }
      }
      inspect-v6 = {
        from_group  = "app"
        destination = { type = "ipv6_cidr", value = "::/0" }
        target = {
          type      = "vpc_endpoint"
          ids_by_az = { us-east-1a = "vpce-a", us-east-1b = "vpce-b" }
        }
      }
      managed-service = {
        from_group  = "app"
        destination = { type = "prefix_list", value = "pl-0123456789abcdef0" }
        target = {
          type      = "network_interface"
          ids_by_az = { us-east-1a = "eni-a", us-east-1b = "eni-b" }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_route.top_level) == 6 &&
      aws_route.top_level["inspect-v4/us-east-1a"].destination_cidr_block == "0.0.0.0/0" &&
      aws_route.top_level["inspect-v6/us-east-1b"].destination_ipv6_cidr_block == "::/0" &&
      aws_route.top_level["managed-service/us-east-1a"].destination_prefix_list_id == "pl-0123456789abcdef0" &&
      aws_route.top_level["inspect-v4/us-east-1a"].vpc_endpoint_id == "vpce-a" &&
      aws_route.top_level["inspect-v4/us-east-1b"].vpc_endpoint_id == "vpce-b" &&
      aws_route.top_level["managed-service/us-east-1b"].network_interface_id == "eni-b"
    )
    error_message = "Zonal targets must select the matching AZ ID for IPv4, IPv6, and prefix-list destinations."
  }
}

run "reject_aggregated_managed_subnet_destination_for_vpc_endpoint" {
  command = plan

  variables {
    vpc                = { name = "aggregated-middlebox-destination" }
    addressing         = { primary = { cidr_block = "10.152.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      application = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.152.10.0/24", us-east-1b = "10.152.11.0/24" } }
      }
      firewall = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.152.20.0/24", us-east-1b = "10.152.21.0/24" } }
      }
    }
    routes = {
      invalid-return = {
        from_group  = "firewall"
        destination = { type = "ipv4_cidr", value = "10.152.10.0/23" }
        target = {
          type      = "vpc_endpoint"
          ids_by_az = { us-east-1a = "vpce-a", us-east-1b = "vpce-b" }
        }
      }
    }
  }

  expect_failures = [terraform_data.top_level_routes_validation]
}

run "allow_exact_managed_subnet_destination_for_vpc_endpoint" {
  command = plan

  variables {
    vpc                = { name = "exact-middlebox-destination" }
    addressing         = { primary = { cidr_block = "10.153.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      application = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.153.10.0/24", us-east-1b = "10.153.11.0/24" } }
      }
      firewall = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.153.20.0/24", us-east-1b = "10.153.21.0/24" } }
      }
    }
    routes = {
      application-a-return = {
        from_group  = "firewall"
        destination = { type = "ipv4_cidr", value = "10.153.10.0/24" }
        target = {
          type      = "vpc_endpoint"
          ids_by_az = { us-east-1a = "vpce-a", us-east-1b = "vpce-b" }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_route.top_level) == 2 &&
      alltrue([for route in values(aws_route.top_level) : route.destination_cidr_block == "10.153.10.0/24"])
    )
    error_message = "A VPC endpoint route that exactly matches a managed subnet CIDR must plan successfully."
  }
}

run "allow_unverifiable_injected_subnet_destination_for_vpc_endpoint" {
  command = plan

  variables {
    vpc                = { name = "injected-subnet-middlebox-destination" }
    addressing         = { primary = { cidr_block = "10.154.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      external-application = {
        role         = "private"
        create       = false
        existing_ids = { us-east-1a = "subnet-external-a", us-east-1b = "subnet-external-b" }
        ipv4         = { cidrs_by_az = { us-east-1a = "10.154.10.0/24", us-east-1b = "10.154.11.0/24" } }
      }
      firewall = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.154.20.0/24", us-east-1b = "10.154.21.0/24" } }
      }
    }
    routes = {
      external-return = {
        from_group  = "firewall"
        destination = { type = "ipv4_cidr", value = "10.154.10.0/23" }
        target = {
          type      = "vpc_endpoint"
          ids_by_az = { us-east-1a = "vpce-a", us-east-1b = "vpce-b" }
        }
      }
    }
  }

  assert {
    condition     = length(aws_route.top_level) == 2
    error_message = "Routes for injected subnet CIDRs must remain caller-validated because the module does not own that subnet topology."
  }
}

run "computed_zonal_targets_do_not_create_a_module_cycle" {
  command = plan

  module {
    source = "./tests/fixtures/zonal-route-composition"
  }

  assert {
    condition = (
      output.composition_shape.endpoint_keys == ["us-east-1a", "us-east-1b"] &&
      output.composition_shape.subnet_keys == ["us-east-1a", "us-east-1b"] &&
      output.composition_shape.route_table_keys == ["us-east-1a", "us-east-1b"]
    )
    error_message = "A target resource consuming VPC subnet outputs must feed computed zonal IDs back into top-level routes without a dependency cycle."
  }
}

run "reject_top_level_target_with_both_id_forms" {
  command = plan

  variables {
    vpc                = { name = "xor-both" }
    addressing         = { primary = { cidr_block = "10.132.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = { role = "private", ipv4 = { cidrs_by_az = { us-east-1a = "10.132.0.0/24" } } }
    }
    routes = {
      invalid = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
        target      = { type = "vpc_endpoint", id = "vpce-static", ids_by_az = { us-east-1a = "vpce-a" } }
      }
    }
  }

  expect_failures = [var.routes]
}

run "reject_top_level_target_with_neither_id_form" {
  command = plan

  variables {
    vpc                = { name = "xor-neither" }
    addressing         = { primary = { cidr_block = "10.133.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = { role = "private", ipv4 = { cidrs_by_az = { us-east-1a = "10.133.0.0/24" } } }
    }
    routes = {
      invalid = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
        target      = { type = "vpc_endpoint" }
      }
    }
  }

  expect_failures = [var.routes]
}

run "reject_unknown_top_level_from_group" {
  command = plan

  variables {
    vpc                = { name = "unknown-group" }
    addressing         = { primary = { cidr_block = "10.134.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = { role = "private", ipv4 = { cidrs_by_az = { us-east-1a = "10.134.0.0/24" } } }
    }
    routes = {
      invalid = {
        from_group  = "missing"
        destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
        target      = { type = "vpc_endpoint", id = "vpce-static" }
      }
    }
  }

  expect_failures = [terraform_data.top_level_routes_validation]
}

run "reject_zonal_target_missing_group_az" {
  command = plan

  variables {
    vpc                = { name = "missing-az" }
    addressing         = { primary = { cidr_block = "10.135.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.135.0.0/24", us-east-1b = "10.135.1.0/24" } }
      }
    }
    routes = {
      invalid = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
        target      = { type = "vpc_endpoint", ids_by_az = { us-east-1a = "vpce-a" } }
      }
    }
  }

  expect_failures = [terraform_data.top_level_routes_validation]
}

run "reject_cross_surface_destination_collision" {
  command = plan

  variables {
    vpc                = { name = "cross-surface-collision" }
    addressing         = { primary = { cidr_block = "10.136.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.136.0.0/24" } }
        routes = {
          legacy = {
            destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
            target      = { type = "vpc_peering", id = "pcx-documentation" }
          }
        }
      }
    }
    routes = {
      late-bound = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
        target      = { type = "vpc_endpoint", id = "vpce-static" }
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_two_top_level_routes_for_one_destination" {
  command = plan

  variables {
    vpc                = { name = "top-level-collision" }
    addressing         = { primary = { cidr_block = "10.137.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = { role = "private", ipv4 = { cidrs_by_az = { us-east-1a = "10.137.0.0/24" } } }
    }
    routes = {
      first = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
        target      = { type = "vpc_endpoint", id = "vpce-first" }
      }
      second = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
        target      = { type = "vpc_endpoint", id = "vpce-second" }
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_top_level_route_key_with_slash" {
  command = plan

  variables {
    vpc                = { name = "slash-key" }
    addressing         = { primary = { cidr_block = "10.138.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = { role = "private", ipv4 = { cidrs_by_az = { us-east-1a = "10.138.0.0/24" } } }
    }
    routes = {
      "invalid/key" = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
        target      = { type = "vpc_endpoint", id = "vpce-static" }
      }
    }
  }

  expect_failures = [var.routes]
}

run "reject_top_level_route_for_isolated_group" {
  command = plan

  variables {
    vpc                = { name = "isolated-top-level" }
    addressing         = { primary = { cidr_block = "10.139.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      data = { role = "isolated", ipv4 = { cidrs_by_az = { us-east-1a = "10.139.0.0/24" } } }
    }
    routes = {
      invalid = {
        from_group  = "data"
        destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
        target      = { type = "vpc_endpoint", id = "vpce-static" }
      }
    }
  }

  expect_failures = [terraform_data.top_level_routes_validation]
}

run "injected_static_target_materializes_once_single_az" {
  command = plan

  variables {
    vpc                = { name = "injected-static-single-az" }
    addressing         = { primary = { cidr_block = "10.142.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.142.0.0/24" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-shared"
      }
    }
    routes = {
      services = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
        target      = { type = "vpc_peering", id = "pcx-documentation" }
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_route.top_level)) == toset(["services/shared"]) &&
      length(distinct([for route in values(aws_route.top_level) : "${route.route_table_id}|${route.destination_cidr_block}"])) == length(aws_route.top_level)
    )
    error_message = "A static route on a one-AZ injected table must have one /shared address and one physical table/destination pair."
  }
}

run "injected_static_target_materializes_once_multiple_azs" {
  command = plan

  variables {
    vpc                = { name = "injected-static-multiple-azs" }
    addressing         = { primary = { cidr_block = "10.143.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.143.0.0/24", us-east-1b = "10.143.1.0/24" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-shared"
      }
    }
    routes = {
      services = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
        target      = { type = "vpc_peering", id = "pcx-documentation" }
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_route.top_level)) == toset(["services/shared"]) &&
      length(distinct([for route in values(aws_route.top_level) : "${route.route_table_id}|${route.destination_cidr_block}"])) == length(aws_route.top_level)
    )
    error_message = "A static route on a multi-AZ injected table must be de-duplicated to one physical table/destination pair."
  }
}

run "reject_zonal_target_on_injected_shared_table" {
  command = plan

  variables {
    vpc                = { name = "injected-zonal-target" }
    addressing         = { primary = { cidr_block = "10.144.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.144.0.0/24", us-east-1b = "10.144.1.0/24" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-shared"
      }
    }
    routes = {
      invalid = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
        target = {
          type      = "vpc_endpoint"
          ids_by_az = { us-east-1a = "vpce-a", us-east-1b = "vpce-b" }
        }
      }
    }
  }

  expect_failures = [terraform_data.top_level_routes_validation]
}

run "reject_prefix_list_route_with_gateway_endpoint_association" {
  command = plan

  variables {
    vpc                = { name = "gateway-endpoint-prefix-conflict" }
    addressing         = { primary = { cidr_block = "10.145.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { us-east-1a = "10.145.0.0/24" } }
        routing = { s3_gateway_endpoint = true }
      }
    }
    gateway_endpoints = { s3 = { service = "s3" } }
    routes = {
      partner-service = {
        from_group  = "app"
        destination = { type = "prefix_list", value = "pl-0123456789abcdef0" }
        target      = { type = "vpc_peering", id = "pcx-documentation" }
      }
    }
  }

  expect_failures = [terraform_data.top_level_routes_validation]
}

run "allow_acknowledged_prefix_list_route_with_gateway_endpoint_association" {
  command = plan

  variables {
    vpc                = { name = "gateway-endpoint-prefix-acknowledged" }
    addressing         = { primary = { cidr_block = "10.146.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { us-east-1a = "10.146.0.0/24" } }
        routing = { s3_gateway_endpoint = true }
      }
    }
    gateway_endpoints = { s3 = { service = "s3" } }
    routes = {
      partner-service = {
        from_group                               = "app"
        acknowledge_gateway_endpoint_coexistence = true
        destination                              = { type = "prefix_list", value = "pl-0123456789abcdef0" }
        target                                   = { type = "vpc_peering", id = "pcx-documentation" }
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_route.top_level)) == toset(["partner-service/us-east-1a"]) &&
      toset(keys(aws_vpc_endpoint_route_table_association.gateway)) == toset(["app/us-east-1a/gateway-endpoint/s3"])
    )
    error_message = "An explicit acknowledgement must allow a distinct prefix-list route to coexist with a gateway endpoint association."
  }
}

run "reject_prefix_list_targeting_vpc_endpoint" {
  command = plan

  variables {
    vpc                = { name = "invalid-prefix-endpoint" }
    addressing         = { primary = { cidr_block = "10.147.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = { role = "private", ipv4 = { cidrs_by_az = { us-east-1a = "10.147.0.0/24" } } }
    }
    routes = {
      invalid = {
        from_group  = "app"
        destination = { type = "prefix_list", value = "pl-0123456789abcdef0" }
        target      = { type = "vpc_endpoint", id = "vpce-static" }
      }
    }
  }

  expect_failures = [var.routes]
}

run "reject_ipv6_cidr_targeting_carrier_gateway" {
  command = plan

  variables {
    vpc                = { name = "invalid-ipv6-carrier" }
    addressing         = { primary = { cidr_block = "10.148.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = { role = "private", ipv4 = { cidrs_by_az = { us-east-1a = "10.148.0.0/24" } } }
    }
    routes = {
      invalid = {
        from_group  = "app"
        destination = { type = "ipv6_cidr", value = "2001:db8:148::/48" }
        target      = { type = "carrier_gateway", id = "cagw-documentation" }
      }
    }
  }

  expect_failures = [var.routes]
}

run "mixed_managed_and_injected_groups_keep_distinct_route_keys" {
  command = plan

  variables {
    vpc                = { name = "mixed-route-table-ownership" }
    addressing         = { primary = { cidr_block = "10.149.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      managed = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.149.0.0/24", us-east-1b = "10.149.1.0/24" } }
      }
      injected = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.149.10.0/24", us-east-1b = "10.149.11.0/24" } }
        manage_route_table = false
        route_table_key    = "shared-services"
        route_table_id     = "rtb-shared-services"
      }
    }
    routes = {
      managed-route = {
        from_group  = "managed"
        destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
        target      = { type = "vpc_peering", id = "pcx-managed" }
      }
      injected-route = {
        from_group  = "injected"
        destination = { type = "ipv4_cidr", value = "10.201.0.0/16" }
        target      = { type = "vpc_peering", id = "pcx-injected" }
      }
    }
  }

  assert {
    condition = toset(keys(aws_route.top_level)) == toset([
      "managed-route/us-east-1a",
      "managed-route/us-east-1b",
      "injected-route/shared",
    ])
    error_message = "One routes map must retain <route-key>/<az> keys for managed tables and <route-key>/shared for an injected table."
  }
}

run "gateway_endpoint_acknowledgement_is_evaluated_per_route" {
  command = plan

  variables {
    vpc                = { name = "per-route-gateway-endpoint-acknowledgement" }
    addressing         = { primary = { cidr_block = "10.150.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { us-east-1a = "10.150.0.0/24" } }
        routing = { s3_gateway_endpoint = true }
      }
    }
    gateway_endpoints = { s3 = { service = "s3" } }
    routes = {
      acknowledged = {
        from_group                               = "app"
        acknowledge_gateway_endpoint_coexistence = true
        destination                              = { type = "prefix_list", value = "pl-0123456789abcdef0" }
        target                                   = { type = "vpc_peering", id = "pcx-acknowledged" }
      }
      unacknowledged = {
        from_group  = "app"
        destination = { type = "prefix_list", value = "pl-0fedcba9876543210" }
        target      = { type = "vpc_peering", id = "pcx-unacknowledged" }
      }
    }
  }

  expect_failures = [terraform_data.top_level_routes_validation]
}

run "reject_cross_surface_collision_on_injected_table" {
  command = plan

  variables {
    vpc                = { name = "injected-cross-surface-collision" }
    addressing         = { primary = { cidr_block = "10.151.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.151.0.0/24", us-east-1b = "10.151.1.0/24" } }
        manage_route_table = false
        route_table_key    = "shared-app"
        route_table_id     = "rtb-shared-app"
        routes = {
          group-route = {
            destination = { type = "ipv4_cidr", value = "10.202.0.0/16" }
            target      = { type = "vpc_peering", id = "pcx-group" }
          }
        }
      }
    }
    routes = {
      late-route = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "10.202.0.0/16" }
        target      = { type = "vpc_endpoint", id = "vpce-late" }
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}
