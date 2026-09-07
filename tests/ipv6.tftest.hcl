mock_provider "aws" {
  override_during = plan
  mock_resource "aws_vpc" {
    defaults = {
      id              = "vpc-mock"
      arn             = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block      = "10.0.0.0/16"
      ipv6_cidr_block = "2001:db8:4200::/56"
    }
  }

  mock_resource "aws_vpc_ipv6_cidr_block_association" {
    defaults = {
      id              = "vpc-cidr-assoc-mock"
      ipv6_cidr_block = "2001:db8:4200::/56"
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

  mock_resource "aws_nat_gateway" {
    defaults = { id = "nat-mock" }
  }

  mock_resource "aws_egress_only_internet_gateway" {
    defaults = { id = "eigw-mock" }
  }
}

run "generated_dual_stack_dns64_eigw" {
  command = plan

  variables {
    vpc                = { name = "ipv6-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" }, secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      public = {
        role    = "public"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24", "us-east-1b" = "10.0.1.0/24" } }
        ipv6    = { secondary_cidr_key = "ipv6", auto_assign = true, cidr_index = 0 }
        routing = { internet_gateway = true }
      }
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.0.10.0/24", "us-east-1b" = "10.0.11.0/24" } }
        ipv6    = { secondary_cidr_key = "ipv6", auto_assign = true, cidr_index = 2 }
        routing = { egress_only_igw = true, dns64 = true }
      }
    }
    nat_gateway = {
      mode         = "single_az"
      az           = "us-east-1a"
      create       = false
      existing_ids = { us-east-1a = "nat-0123456789abcdef0" }
    }
  }

  assert {
    condition     = aws_vpc_ipv6_cidr_block_association.secondary["ipv6"].assign_generated_ipv6_cidr_block
    error_message = "Amazon-provided IPv6 must use a standalone secondary association."
  }

  assert {
    condition = (
      aws_subnet.main["public/us-east-1a"].ipv6_cidr_block == "2001:db8:4200::/64" &&
      aws_subnet.main["public/us-east-1b"].ipv6_cidr_block == "2001:db8:4200:1::/64" &&
      aws_subnet.main["app/us-east-1a"].ipv6_cidr_block == "2001:db8:4200:6::/64" &&
      aws_subnet.main["app/us-east-1b"].ipv6_cidr_block == "2001:db8:4200:7::/64" &&
      alltrue([for subnet in values(aws_subnet.main) : subnet.assign_ipv6_address_on_creation])
    )
    error_message = "auto_assign must plan deterministic, pinned /64s and enable address assignment."
  }

  assert {
    condition = (
      length(aws_route.eigw) == 2 &&
      alltrue([for route in values(aws_route.eigw) : route.destination_ipv6_cidr_block == "::/0"]) &&
      length(aws_route.nat64) == 2 &&
      alltrue([for route in values(aws_route.nat64) : route.destination_ipv6_cidr_block == "64:ff9b::/96"])
    )
    error_message = "EIGW and DNS64 must plan complete ::/0 and NAT64 routes."
  }
}

run "vpc_and_subnet_ipv6_ipam" {
  command = plan

  variables {
    vpc = { name = "ipv6-ipam-test" }
    addressing = {
      primary   = { cidr_block = "10.0.0.0/16" }
      secondary = { ipv6 = { ipv6 = { ipam_pool_id = "ipam-pool-vpc", netmask_length = 56 } } }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      application = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
        ipv6 = { secondary_cidr_key = "ipv6", ipam_pool_id = "ipam-pool-subnet", netmask_length = 64, auto_assign = true }
      }
    }
  }

  assert {
    condition = (
      aws_vpc_ipv6_cidr_block_association.secondary["ipv6"].ipv6_ipam_pool_id == "ipam-pool-vpc" &&
      aws_vpc_ipv6_cidr_block_association.secondary["ipv6"].ipv6_netmask_length == 56
    )
    error_message = "VPC IPv6 IPAM must pass pool and netmask without an explicit CIDR."
  }

  assert {
    condition = (
      aws_subnet.main["application/us-east-1a"].ipv6_ipam_pool_id == "ipam-pool-subnet" &&
      aws_subnet.main["application/us-east-1a"].ipv6_netmask_length == 64 &&
      aws_subnet.main["application/us-east-1a"].assign_ipv6_address_on_creation
    )
    error_message = "Subnet IPv6 IPAM attributes must be planned explicitly."
  }
}

run "explicit_vpc_ipv6_ipam_cidr" {
  command = plan

  variables {
    vpc = { name = "ipv6-explicit-test" }
    addressing = {
      primary   = { cidr_block = "10.0.0.0/16" }
      secondary = { ipv6 = { ipv6 = { ipam_pool_id = "ipam-pool-vpc", cidr_block = "2001:db8:100::/56" } } }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      native = {
        role = "private"
        ipv6 = { secondary_cidr_key = "ipv6", native_only = true, auto_assign = true }
      }
    }
  }

  assert {
    condition = (
      aws_vpc_ipv6_cidr_block_association.secondary["ipv6"].ipv6_ipam_pool_id == "ipam-pool-vpc" &&
      aws_vpc_ipv6_cidr_block_association.secondary["ipv6"].ipv6_cidr_block == "2001:db8:100::/56" &&
      aws_vpc_ipv6_cidr_block_association.secondary["ipv6"].ipv6_netmask_length == null
    )
    error_message = "Explicit VPC IPv6 CIDRs must be passed with their IPAM pool."
  }

  assert {
    condition = (
      aws_subnet.main["native/us-east-1a"].ipv6_native &&
      aws_subnet.main["native/us-east-1a"].ipv6_cidr_block == "2001:db8:100::/64"
    )
    error_message = "IPv6-native subnets must plan a real /64 and no IPv4 CIDR."
  }
}


run "ipv6_native_enables_aaaa_resource_names" {
  command = plan

  variables {
    vpc                = { name = "ipv6-native-dns" }
    addressing         = { primary = { cidr_block = "10.9.0.0/16" }, secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      native = {
        role = "private"
        ipv6 = { secondary_cidr_key = "ipv6", native_only = true, auto_assign = true }
      }
    }
  }

  assert {
    condition = (
      aws_subnet.main["native/us-east-1a"].ipv6_native &&
      aws_subnet.main["native/us-east-1a"].enable_resource_name_dns_aaaa_record_on_launch
    )
    error_message = "IPv6-native subnets must enable AAAA resource-name DNS records because EC2 rejects false without an IPv4 CIDR."
  }
}

run "multiple_ipv6_secondaries_are_caller_keyed" {
  command = plan

  variables {
    vpc = { name = "multiple-ipv6" }
    addressing = {
      primary = { cidr_block = "10.10.0.0/16" }
      secondary = {
        amazon = { ipv6 = { amazon_assigned = true } }
        ipam = {
          ipv6 = {
            ipam_pool_id = "ipam-pool-vpc"
            cidr_block   = "2001:db8:5200::/52"
          }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      amazon-native = {
        role = "private"
        ipv6 = { secondary_cidr_key = "amazon", native_only = true, auto_assign = true, cidr_index = 0 }
      }
      ipam-native = {
        role = "private"
        ipv6 = { secondary_cidr_key = "ipam", native_only = true, auto_assign = true, cidr_index = 0 }
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_vpc_ipv6_cidr_block_association.secondary)) == toset(["amazon", "ipam"]) &&
      aws_vpc_ipv6_cidr_block_association.secondary["amazon"].assign_generated_ipv6_cidr_block &&
      aws_vpc_ipv6_cidr_block_association.secondary["ipam"].ipv6_ipam_pool_id == "ipam-pool-vpc" &&
      aws_vpc_ipv6_cidr_block_association.secondary["ipam"].ipv6_cidr_block == "2001:db8:5200::/52" &&
      toset(keys(output.vpc_ipv6_cidr_blocks)) == toset(["amazon", "ipam"])
    )
    error_message = "Every IPv6 secondary must retain caller-owned identity and independent source arguments."
  }

  assert {
    condition = (
      aws_subnet.main["amazon-native/us-east-1a"].ipv6_cidr_block == "2001:db8:4200::/64" &&
      aws_subnet.main["ipam-native/us-east-1a"].ipv6_cidr_block == "2001:db8:5200::/64" &&
      aws_subnet.main["amazon-native/us-east-1a"].ipv6_native &&
      aws_subnet.main["ipam-native/us-east-1a"].ipv6_native
    )
    error_message = "IPv6-only subnets must derive deterministic /64s from their selected secondary range; equal pins are valid across different ranges."
  }
}

run "reject_ipv6_subnet_without_secondary_key" {
  command = plan

  variables {
    vpc                = { name = "missing-ipv6-key" }
    addressing         = { primary = { cidr_block = "10.11.0.0/16" }, secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { netmask = 24 }
        ipv6 = { auto_assign = true }
      }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_unknown_ipv6_secondary_key" {
  command = plan

  variables {
    vpc                = { name = "unknown-ipv6-key" }
    addressing         = { primary = { cidr_block = "10.12.0.0/16" }, secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { netmask = 24 }
        ipv6 = {
          secondary_cidr_key = "missing"
          ipam_pool_id       = "ipam-pool-subnet"
          netmask_length     = 64
        }
      }
    }
  }

  expect_failures = [terraform_data.subnet_ipv6_secondary_cidr_validation["app/us-east-1a"]]
}

run "reject_explicit_ipv6_outside_selected_parent" {
  command = plan

  variables {
    vpc = { name = "ipv6-containment" }
    addressing = {
      primary = { cidr_block = "10.13.0.0/16" }
      secondary = {
        blue = {
          ipv6 = { ipam_pool_id = "ipam-pool-blue", cidr_block = "2001:db8:1000::/56" }
        }
        green = {
          ipv6 = { ipam_pool_id = "ipam-pool-green", cidr_block = "2001:db8:2000::/56" }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.13.0.0/24" } }
        ipv6 = {
          secondary_cidr_key = "blue"
          cidrs_by_az        = { us-east-1a = "2001:db8:2000::/64" }
        }
      }
    }
  }

  expect_failures = [terraform_data.subnet_ipv6_secondary_cidr_validation["app/us-east-1a"]]
}

run "reject_duplicate_injected_ipv6_association" {
  command = plan

  variables {
    vpc = { name = "duplicate-injected-ipv6" }
    addressing = {
      primary = { cidr_block = "10.14.0.0/16" }
      secondary = {
        blue = {
          ipv6 = {
            create         = false
            association_id = "vpc-cidr-assoc-0123456789abcdef0"
          }
        }
        green = {
          ipv6 = {
            create         = false
            association_id = "vpc-cidr-assoc-0123456789abcdef0"
          }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      blue = {
        role = "private"
        ipv6 = { secondary_cidr_key = "blue", native_only = true, auto_assign = true, cidr_index = 0 }
      }
      green = {
        role = "private"
        ipv6 = { secondary_cidr_key = "green", native_only = true, auto_assign = true, cidr_index = 0 }
      }
    }
  }

  expect_failures = [var.addressing]
}

run "subnet_ipv6_ipam_selector_preserves_separate_pool" {
  command = plan

  variables {
    vpc = { name = "subnet-ipam-selector-v6" }
    addressing = {
      primary = { cidr_block = "10.31.0.0/16" }
      secondary = {
        blue = { ipv6 = { ipam_pool_id = "ipam-pool-vpc-blue-v6", netmask_length = 56 } }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.31.0.0/24" } }
        ipv6 = {
          secondary_cidr_key = "blue"
          ipam_pool_id       = "ipam-pool-subnet-child-v6"
          netmask_length     = 64
          auto_assign        = true
        }
      }
    }
  }

  assert {
    condition = (
      terraform_data.subnet_ipv6_secondary_cidr_validation["app/us-east-1a"].input == aws_vpc_ipv6_cidr_block_association.secondary["blue"].id &&
      aws_subnet.main["app/us-east-1a"].ipv6_ipam_pool_id == "ipam-pool-subnet-child-v6"
    )
    error_message = "IPv6 subnet IPAM must retain the selected association dependency without pretending the subnet pool ID equals its VPC parent pool."
  }
}
