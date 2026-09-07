mock_provider "aws" {
  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = {
      id  = "subnet-mock"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
    }
  }

  mock_resource "aws_route_table" {
    defaults = { id = "rtb-mock" }
  }
}

run "reject_invalid_subnet_role" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = { role = "invalid", ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } } }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_duplicate_pinned_index" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app  = { role = "private", ipv4 = { netmask = 24, cidr_index = 1 } }
      data = { role = "private", ipv4 = { netmask = 24, cidr_index = 1 } }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_isolated_routing" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      data = {
        role    = "isolated"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
        routing = { transit_gateway = ["10.0.0.0/8"] }
      }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_conflicting_vpc_ipv4_sources" {
  command = plan

  variables {
    vpc = { name = "negative-test" }
    addressing = {
      primary = {
        cidr_block     = "10.0.0.0/16"
        ipam_pool_id   = "ipam-pool-0123456789abcdef0"
        netmask_length = 16
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
  }

  expect_failures = [var.addressing]
}

run "reject_single_az_nat_without_az" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    nat_gateway        = { mode = "single_az" }
  }

  expect_failures = [var.nat_gateway]
}

run "reject_cidr_count_mismatch" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24", "us-east-1b" = "10.0.1.0/24", "us-east-1c" = "10.0.2.0/24" } }
      }
    }
  }

  expect_failures = [terraform_data.cidrs_az_count_validation["app"]]
}

run "reject_nat_az_outside_vpc_azs" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets            = {}
    nat_gateway = {
      mode   = "single_az"
      az     = "us-east-1c"
      create = false
      existing_ids = {
        us-east-1c = "nat-0123456789abcdef0"
      }
    }
  }

  expect_failures = [terraform_data.nat_gateway_az_validation[0]]
}

run "reject_nat_route_without_gateway" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
        routing = { nat_gateway = true }
      }
    }
  }

  expect_failures = [terraform_data.nat_routing_requires_nat_gateway[0]]
}

run "reject_shared_route_table_with_all_az_nat" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role               = "private"
        manage_route_table = false
        route_table_key    = "shared-app"
        route_table_id     = "rtb-existing"
        ipv4               = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24", "us-east-1b" = "10.0.1.0/24" } }
        routing            = { nat_gateway = true }
      }
    }
    nat_gateway = {
      mode   = "all_azs"
      create = false
      existing_ids = {
        us-east-1a = "nat-aaa"
        us-east-1b = "nat-bbb"
      }
    }
  }

  expect_failures = [terraform_data.injected_route_table_all_az_nat_validation["app"]]
}

run "reject_tgw_routes_without_attachment_group" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
        routing = { transit_gateway = ["10.0.0.0/8"] }
      }
    }
  }

  expect_failures = [terraform_data.attachment_contract_validation]
}

run "reject_overlapping_pins_across_netmasks" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      application = { role = "private", ipv4 = { netmask = 22, cidr_index = 0 } }
      endpoints   = { role = "private", ipv4 = { netmask = 24, cidr_index = 0 } }
    }
  }

  expect_failures = [terraform_data.cidr_pinning_validation[0]]
}

run "reject_isolated_dns64" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" }, secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      data = {
        role    = "isolated"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
        ipv6    = { secondary_cidr_key = "ipv6", auto_assign = true }
        routing = { dns64 = true }
      }
    }
    nat_gateway = {
      mode         = "single_az"
      az           = "us-east-1a"
      create       = false
      existing_ids = { us-east-1a = "nat-0123456789abcdef0" }
    }
  }

  expect_failures = [var.subnets]
}

run "public_can_disable_internet_gateway" {
  command = plan

  variables {
    vpc                = { name = "no-igw-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      edge = {
        role    = "public"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
        routing = { internet_gateway = false }
      }
    }
  }

  assert {
    condition     = length(aws_internet_gateway.main) == 0 && length(aws_route.igw_ipv4) == 0
    error_message = "internet_gateway=false on a public group must suppress both the IGW and default route."
  }
}


run "reject_invalid_flow_log_name_format" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.9.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    flow_logs = {
      invalid = {
        destination_type = "s3"
        destination_arn  = "arn:aws:s3:::invalid-format-bucket"
        name_format      = "{vpc}-{unknown}"
      }
    }
  }

  expect_failures = [var.flow_logs]
}


run "public_ip_assignment_is_opt_in" {
  command = plan

  variables {
    vpc                = { name = "public-ip-opt-in" }
    addressing         = { primary = { cidr_block = "10.95.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      default_public = {
        role = "public"
        ipv4 = { netmask = 24, cidr_index = 0 }
      }
      explicit_public = {
        role           = "public"
        ipv4           = { netmask = 24, cidr_index = 1 }
        public_options = { map_public_ip = true }
      }
    }
  }

  assert {
    condition = (
      aws_subnet.main["default_public/us-east-1a"].map_public_ip_on_launch == false &&
      aws_subnet.main["explicit_public/us-east-1a"].map_public_ip_on_launch == true
    )
    error_message = "Public subnet IPv4 auto-assignment must default false and require explicit opt-in."
  }
}

run "nat_gateway_null_uses_non_null_default" {
  command = plan

  variables {
    vpc                = { name = "nullable-default" }
    addressing         = { primary = { cidr_block = "10.110.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    nat_gateway        = null
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 0
    error_message = "nullable=false must normalize explicit nat_gateway=null to the declared non-null default instead of dereferencing null."
  }
}

run "reject_vpc_ipv4_orphan_netmask_length" {
  command = plan

  variables {
    vpc                = { name = "orphan-vpc-netmask" }
    addressing         = { primary = { cidr_block = "10.112.0.0/16", netmask_length = 16 } }
    availability_zones = { names = ["us-east-1a"] }
  }

  expect_failures = [var.addressing]
}

run "reject_subnet_ipv4_orphan_netmask_length" {
  command = plan

  variables {
    vpc                = { name = "orphan-subnet-netmask" }
    addressing         = { primary = { cidr_block = "10.113.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.113.0.0/24" }, netmask_length = 24 }
      }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_cidr_index_outside_calculated_mode" {
  command = plan

  variables {
    vpc                = { name = "orphan-cidr-index" }
    addressing         = { primary = { cidr_block = "10.114.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.114.0.0/24" }, cidr_index = 1 }
      }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_ipv6_orphan_netmask_length" {
  command = plan

  variables {
    vpc                = { name = "orphan-ipv6-netmask" }
    addressing         = { primary = { cidr_block = "10.115.0.0/16" }, secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.115.0.0/24" } }
        ipv6 = { secondary_cidr_key = "ipv6", auto_assign = true, netmask_length = 64 }
      }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_ipv6_native_with_ipv4" {
  command = plan

  variables {
    vpc                = { name = "mixed-native" }
    addressing         = { primary = { cidr_block = "10.116.0.0/16" }, secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.116.0.0/24" } }
        ipv6 = { secondary_cidr_key = "ipv6", native_only = true, auto_assign = true }
      }
    }
  }

  expect_failures = [var.subnets]
}

run "isolated_accepts_explicit_empty_route_lists" {
  command = plan

  variables {
    vpc                = { name = "isolated-empty-routes" }
    addressing         = { primary = { cidr_block = "10.117.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      data = {
        role = "isolated"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.117.0.0/24" } }
        routing = {
          transit_gateway      = []
          transit_gateway_ipv6 = []
          core_network         = []
          core_network_ipv6    = []
        }
      }
    }
  }

  assert {
    condition     = length(aws_route.tgw) == 0 && length(aws_route.cwan) == 0
    error_message = "Explicit empty transit route lists must preserve isolated semantics."
  }
}

run "reject_empty_subnet_name_format" {
  command = plan

  variables {
    vpc                = { name = "empty-format" }
    addressing         = { primary = { cidr_block = "10.118.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = { role = "private", name_format = "", ipv4 = { cidrs_by_az = { us-east-1a = "10.118.0.0/24" } } }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_empty_nat_name_format" {
  command = plan

  variables {
    vpc                = { name = "empty-nat-format" }
    addressing         = { primary = { cidr_block = "10.119.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    nat_gateway        = { mode = "none", name_format = "" }
  }

  expect_failures = [var.nat_gateway]
}

run "reject_calculated_cidr_pin_beyond_parent_capacity" {
  command = plan

  variables {
    vpc                = { name = "pin-capacity" }
    addressing         = { primary = { cidr_block = "10.120.0.0/24" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = { role = "private", ipv4 = { netmask = 28, cidr_index = 6 } }
    }
  }

  expect_failures = [
    aws_subnet.main,
    terraform_data.cidr_pinning_validation[0],
  ]
}
