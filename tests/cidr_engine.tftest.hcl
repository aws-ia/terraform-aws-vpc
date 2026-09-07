mock_provider "aws" {
  mock_resource "aws_vpc" {
    defaults = {
      id  = "vpc-mock"
      arn = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
    }
  }

  mock_resource "aws_subnet" {
    defaults = {
      id  = "subnet-mock"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
    }
  }

  mock_resource "aws_route_table" {
    defaults = {
      id = "rtb-mock"
    }
  }
}

run "unpinned_before_group_add" {
  command = plan

  variables {
    calculated_subnet_az_capacity = 6
    vpc                           = { name = "cidr-test" }
    addressing                    = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones            = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      alpha = { role = "private", ipv4 = { netmask = 24 } }
      gamma = { role = "private", ipv4 = { netmask = 24 } }
    }
  }

  assert {
    condition = (
      keys(output.subnet_cidrs_by_group_by_az) == ["alpha", "gamma"] && alltrue([
        keys(output.subnet_cidrs_by_group_by_az.alpha) == ["us-east-1a", "us-east-1b"],
        keys(output.subnet_cidrs_by_group_by_az.gamma) == ["us-east-1a", "us-east-1b"],
      ])
    )
    error_message = "Unpinned subnet keys must be exact and AZ-nested."
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az == {
        alpha = { us-east-1a = "10.0.0.0/24", us-east-1b = "10.0.1.0/24" }
        gamma = { us-east-1a = "10.0.6.0/24", us-east-1b = "10.0.7.0/24" }
      }
    )
    error_message = "The baseline unpinned CIDR allocation changed."
  }
}

run "unpinned_after_group_add" {
  command = plan

  variables {
    calculated_subnet_az_capacity = 6
    vpc                           = { name = "cidr-test" }
    addressing                    = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones            = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      alpha = { role = "private", ipv4 = { netmask = 24 } }
      beta  = { role = "private", ipv4 = { netmask = 24 } }
      gamma = { role = "private", ipv4 = { netmask = 24 } }
    }
  }

  assert {
    condition     = keys(output.subnet_cidrs_by_group_by_az) == ["alpha", "beta", "gamma"]
    error_message = "Adding an unpinned group must add exactly that group key."
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az == {
        alpha = { us-east-1a = "10.0.0.0/24", us-east-1b = "10.0.1.0/24" }
        beta  = { us-east-1a = "10.0.6.0/24", us-east-1b = "10.0.7.0/24" }
        gamma = { us-east-1a = "10.0.12.0/24", us-east-1b = "10.0.13.0/24" }
      }
    )
    error_message = "Unpinned groups that sort after an insertion must shift deterministically."
  }
}

run "unpinned_after_group_remove" {
  command = plan

  variables {
    calculated_subnet_az_capacity = 6
    vpc                           = { name = "cidr-test" }
    addressing                    = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones            = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      alpha = { role = "private", ipv4 = { netmask = 24 } }
      gamma = { role = "private", ipv4 = { netmask = 24 } }
    }
  }

  assert {
    condition     = keys(output.subnet_cidrs_by_group_by_az) == ["alpha", "gamma"]
    error_message = "Removing an unpinned group must remove exactly that group key."
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az == {
        alpha = { us-east-1a = "10.0.0.0/24", us-east-1b = "10.0.1.0/24" }
        gamma = { us-east-1a = "10.0.6.0/24", us-east-1b = "10.0.7.0/24" }
      }
    )
    error_message = "Removing an earlier unpinned group must compact later groups deterministically."
  }
}

run "pinned_before_group_add" {
  command = plan

  variables {
    calculated_subnet_az_capacity = 6
    vpc                           = { name = "cidr-test" }
    addressing                    = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones            = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      alpha = { role = "private", ipv4 = { netmask = 24, cidr_index = 0 } }
      gamma = { role = "private", ipv4 = { netmask = 24, cidr_index = 5 } }
    }
  }

  assert {
    condition     = keys(output.subnet_cidrs_by_group_by_az) == ["alpha", "gamma"]
    error_message = "Pinned baseline keys must be exact."
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az == {
        alpha = { us-east-1a = "10.0.0.0/24", us-east-1b = "10.0.1.0/24" }
        gamma = { us-east-1a = "10.0.30.0/24", us-east-1b = "10.0.31.0/24" }
      }
    )
    error_message = "Pinned CIDR slots must reserve six AZ positions per group."
  }
}

run "pinned_after_group_add" {
  command = plan

  variables {
    calculated_subnet_az_capacity = 6
    vpc                           = { name = "cidr-test" }
    addressing                    = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones            = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      alpha = { role = "private", ipv4 = { netmask = 24, cidr_index = 0 } }
      beta  = { role = "private", ipv4 = { netmask = 24 } }
      gamma = { role = "private", ipv4 = { netmask = 24, cidr_index = 5 } }
    }
  }

  assert {
    condition     = keys(output.subnet_cidrs_by_group_by_az) == ["alpha", "beta", "gamma"]
    error_message = "Adding an unpinned group beside pinned groups must add exactly one key."
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az == {
        alpha = { us-east-1a = "10.0.0.0/24", us-east-1b = "10.0.1.0/24" }
        beta  = { us-east-1a = "10.0.36.0/24", us-east-1b = "10.0.37.0/24" }
        gamma = { us-east-1a = "10.0.30.0/24", us-east-1b = "10.0.31.0/24" }
      }
    )
    error_message = "Adding an unpinned group must not move pinned groups."
  }
}

run "pinned_after_group_remove" {
  command = plan

  variables {
    calculated_subnet_az_capacity = 6
    vpc                           = { name = "cidr-test" }
    addressing                    = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones            = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      alpha = { role = "private", ipv4 = { netmask = 24, cidr_index = 0 } }
      gamma = { role = "private", ipv4 = { netmask = 24, cidr_index = 5 } }
    }
  }

  assert {
    condition     = keys(output.subnet_cidrs_by_group_by_az) == ["alpha", "gamma"]
    error_message = "Removing an unpinned group from a pinned layout must remove exactly one key."
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az == {
        alpha = { us-east-1a = "10.0.0.0/24", us-east-1b = "10.0.1.0/24" }
        gamma = { us-east-1a = "10.0.30.0/24", us-east-1b = "10.0.31.0/24" }
      }
    )
    error_message = "Removing an unpinned group must not move pinned groups."
  }
}

run "add_availability_zone" {
  command = plan

  variables {
    calculated_subnet_az_capacity = 6
    vpc                           = { name = "cidr-test" }
    addressing                    = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones            = { names = ["us-east-1a", "us-east-1b", "us-east-1c"] }
    subnets = {
      alpha = { role = "private", ipv4 = { netmask = 24 } }
      gamma = { role = "private", ipv4 = { netmask = 24 } }
    }
  }

  assert {
    condition = (
      alltrue([
        keys(output.subnet_cidrs_by_group_by_az.alpha) == ["us-east-1a", "us-east-1b", "us-east-1c"],
        keys(output.subnet_cidrs_by_group_by_az.gamma) == ["us-east-1a", "us-east-1b", "us-east-1c"],
      ])
    )
    error_message = "Adding an AZ must append exactly one nested AZ key per group."
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az == {
        alpha = { us-east-1a = "10.0.0.0/24", us-east-1b = "10.0.1.0/24", us-east-1c = "10.0.2.0/24" }
        gamma = { us-east-1a = "10.0.6.0/24", us-east-1b = "10.0.7.0/24", us-east-1c = "10.0.8.0/24" }
      }
    )
    error_message = "Adding an AZ must preserve existing AZ CIDRs and consume the reserved next slot."
  }
}

run "explicit_cidrs" {
  command = plan

  variables {
    vpc                = { name = "cidr-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.100.0/24", "us-east-1b" = "10.0.200.0/24" } }
      }
    }
  }

  assert {
    condition = (
      keys(output.subnet_cidrs_by_group_by_az) == ["app"] &&
      keys(output.subnet_cidrs_by_group_by_az.app) == ["us-east-1a", "us-east-1b"]
    )
    error_message = "Explicit CIDR output keys must match the group and configured AZs exactly."
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az.app == {
        us-east-1a = "10.0.100.0/24"
        us-east-1b = "10.0.200.0/24"
      }
    )
    error_message = "Explicit CIDRs must pass through unchanged in AZ order."
  }
}

run "explicit_cidrs_before_middle_az_insert" {
  command = plan

  variables {
    vpc                = { name = "explicit-az-map" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1c"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = {
          cidrs_by_az = {
            us-east-1a = "10.0.100.0/24"
            us-east-1c = "10.0.200.0/24"
          }
        }
      }
    }
  }

  assert {
    condition = output.subnet_cidrs_by_group_by_az.app == {
      us-east-1a = "10.0.100.0/24"
      us-east-1c = "10.0.200.0/24"
    }
    error_message = "Explicit CIDRs must be selected by AZ identity before insertion."
  }
}

run "explicit_cidrs_after_middle_az_insert" {
  command = plan

  variables {
    vpc                = { name = "explicit-az-map" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b", "us-east-1c"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = {
          cidrs_by_az = {
            us-east-1a = "10.0.100.0/24"
            us-east-1b = "10.0.150.0/24"
            us-east-1c = "10.0.200.0/24"
          }
        }
      }
    }
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az.app["us-east-1a"] == "10.0.100.0/24" &&
      output.subnet_cidrs_by_group_by_az.app["us-east-1c"] == "10.0.200.0/24"
    )
    error_message = "Inserting an AZ in the middle must not reassign explicit CIDRs for existing AZ keys."
  }
}

run "mixed_netmasks_pack_without_overlap" {
  command = plan

  variables {
    calculated_subnet_az_capacity = 6
    vpc                           = { name = "cidr-test" }
    addressing                    = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones            = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      application = { role = "private", ipv4 = { netmask = 22 } }
      public      = { role = "public", ipv4 = { netmask = 24 } }
    }
  }

  assert {
    condition = (
      toset(keys(output.subnet_cidrs_by_group_by_az)) == toset(["application", "public"])
    )
    error_message = "Mixed-netmask allocation must retain both exact group keys."
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az == {
        application = { us-east-1a = "10.0.0.0/22", us-east-1b = "10.0.4.0/22" }
        public      = { us-east-1a = "10.0.24.0/24", us-east-1b = "10.0.25.0/24" }
      }
    )
    error_message = "Mixed netmasks must pack largest-first without overlapping their six-AZ reservations."
  }
}

run "explicit_ipv4_inside_primary_parent" {
  command = plan

  variables {
    vpc                = { name = "primary-containment-positive" }
    addressing         = { primary = { cidr_block = "10.20.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.20.10.0/24" } }
      }
    }
  }

  assert {
    condition     = aws_subnet.main["app/us-east-1a"].cidr_block == "10.20.10.0/24"
    error_message = "An explicit IPv4 CIDR inside the primary VPC CIDR must remain valid."
  }
}

run "reject_explicit_ipv4_outside_primary_parent" {
  command = plan

  variables {
    vpc                = { name = "primary-containment-negative" }
    addressing         = { primary = { cidr_block = "10.20.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "192.168.10.0/24" } }
      }
    }
  }

  expect_failures = [terraform_data.subnet_secondary_cidr_validation["app/us-east-1a"]]
}

run "constrained_three_az_capacity_fits_three_pinned_28_groups_in_a_24" {
  command = plan

  variables {
    vpc                = { name = "inspection-24" }
    addressing         = { primary = { cidr_block = "10.0.0.0/24" } }
    availability_zones = { names = ["eu-south-2a"] }
    subnets = {
      core_network = { role = "private", ipv4 = { netmask = 28, cidr_index = 0 } }
      firewall     = { role = "private", ipv4 = { netmask = 28, cidr_index = 1 } }
      public       = { role = "public", ipv4 = { netmask = 28, cidr_index = 2 } }
    }
  }

  assert {
    condition = output.subnet_cidrs_by_group_by_az == {
      core_network = { eu-south-2a = "10.0.0.0/28" }
      firewall     = { eu-south-2a = "10.0.0.48/28" }
      public       = { eu-south-2a = "10.0.0.96/28" }
    }
    error_message = "A /24 must fit the three inspection /28 groups while reserving three stable AZ slots per group."
  }
}

run "constrained_three_az_capacity_allocates_every_availability_zone" {
  command = plan

  variables {
    vpc                = { name = "inspection-24" }
    addressing         = { primary = { cidr_block = "10.0.0.0/24" } }
    availability_zones = { names = ["eu-south-2a", "eu-south-2b", "eu-south-2c"] }
    subnets = {
      core_network = { role = "private", ipv4 = { netmask = 28, cidr_index = 0 } }
      firewall     = { role = "private", ipv4 = { netmask = 28, cidr_index = 1 } }
      public       = { role = "public", ipv4 = { netmask = 28, cidr_index = 2 } }
    }
  }

  assert {
    condition = output.subnet_cidrs_by_group_by_az == {
      core_network = {
        eu-south-2a = "10.0.0.0/28"
        eu-south-2b = "10.0.0.16/28"
        eu-south-2c = "10.0.0.32/28"
      }
      firewall = {
        eu-south-2a = "10.0.0.48/28"
        eu-south-2b = "10.0.0.64/28"
        eu-south-2c = "10.0.0.80/28"
      }
      public = {
        eu-south-2a = "10.0.0.96/28"
        eu-south-2b = "10.0.0.112/28"
        eu-south-2c = "10.0.0.128/28"
      }
    }
    error_message = "Filling the three reserved AZ slots must allocate consecutive /28 blocks per group without exceeding the /24."
  }
}

run "constrained_capacity_scale_up_preserves_existing_az_cidrs" {
  command = plan

  variables {
    vpc                = { name = "inspection-24" }
    addressing         = { primary = { cidr_block = "10.0.0.0/24" } }
    availability_zones = { names = ["eu-south-2a", "eu-south-2b"] }
    subnets = {
      core_network = { role = "private", ipv4 = { netmask = 28, cidr_index = 0 } }
      firewall     = { role = "private", ipv4 = { netmask = 28, cidr_index = 1 } }
      public       = { role = "public", ipv4 = { netmask = 28, cidr_index = 2 } }
    }
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az.core_network["eu-south-2a"] == "10.0.0.0/28" &&
      output.subnet_cidrs_by_group_by_az.firewall["eu-south-2a"] == "10.0.0.48/28" &&
      output.subnet_cidrs_by_group_by_az.public["eu-south-2a"] == "10.0.0.96/28"
    )
    error_message = "Growing from one AZ to two must keep the first AZ on the same /28 blocks (scale-up without renumbering)."
  }

  assert {
    condition = (
      output.subnet_cidrs_by_group_by_az.core_network["eu-south-2b"] == "10.0.0.16/28" &&
      output.subnet_cidrs_by_group_by_az.firewall["eu-south-2b"] == "10.0.0.64/28" &&
      output.subnet_cidrs_by_group_by_az.public["eu-south-2b"] == "10.0.0.112/28"
    )
    error_message = "The second AZ must take the next reserved slot of each group without touching neighbouring groups."
  }
}
