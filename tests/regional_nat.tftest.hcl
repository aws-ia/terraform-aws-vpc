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
      id  = "subnet-mock"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
    }
  }

  mock_resource "aws_route_table" {
    defaults = { id = "rtb-mock" }
  }

  mock_resource "aws_internet_gateway" {
    defaults = { id = "igw-mock" }
  }

  mock_resource "aws_eip" {
    defaults = { id = "eipalloc-created" }
  }

  mock_resource "aws_nat_gateway" {
    defaults = {
      id             = "nat-regional-mock"
      route_table_id = "rtb-regional-mock"
      regional_nat_gateway_address = [
        {
          allocation_id        = "eipalloc-a"
          association_id       = "eipassoc-a"
          availability_zone    = "us-east-1a"
          availability_zone_id = "use1-az1"
          network_interface_id = "eni-a"
          public_ip            = "198.51.100.10"
          status               = "succeeded"
        },
        {
          allocation_id        = "eipalloc-b"
          association_id       = "eipassoc-b"
          availability_zone    = "us-east-1b"
          availability_zone_id = "use1-az2"
          network_interface_id = "eni-b"
          public_ip            = "198.51.100.11"
          status               = "succeeded"
        }
      ]
    }
  }
}

run "regional_auto_mode" {
  command = plan

  variables {
    vpc                = { name = "regional-auto" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24", "us-east-1b" = "10.0.1.0/24" } }
        routing = { nat_gateway = true }
      }
    }
    nat_gateway = { mode = "regional" }
  }

  assert {
    condition = (
      length(aws_nat_gateway.main) == 1 &&
      aws_nat_gateway.main["nat/regional"].availability_mode == "regional" &&
      aws_nat_gateway.main["nat/regional"].connectivity_type == "public" &&
      aws_nat_gateway.main["nat/regional"].vpc_id == "vpc-mock" &&
      aws_nat_gateway.main["nat/regional"].subnet_id == null &&
      length(aws_nat_gateway.main["nat/regional"].availability_zone_address) == 0 &&
      length(aws_eip.nat) == 0 && length(aws_internet_gateway.main) == 1
    )
    error_message = "Regional auto mode must create one public VPC-level NAT with no subnet or module-owned EIPs."
  }

  assert {
    condition = (
      toset(keys(output.nat_gateway_ids)) == toset(["us-east-1a", "us-east-1b"]) &&
      output.nat_gateway_ids["us-east-1a"] == "nat-regional-mock" &&
      output.nat_gateway_ids["us-east-1b"] == "nat-regional-mock" &&
      aws_route.nat["app/us-east-1a/nat"].nat_gateway_id == "nat-regional-mock" &&
      aws_route.nat["app/us-east-1b/nat"].nat_gateway_id == "nat-regional-mock"
    )
    error_message = "Every private route and AZ-keyed Tier 1 handle must resolve to the one Regional NAT ID."
  }

  assert {
    condition = (
      output.regional_nat_gateway_route_table_id == "rtb-regional-mock" &&
      toset(keys(output.nat_public_ips)) == toset(["us-east-1a/eipalloc-a", "us-east-1b/eipalloc-b"]) &&
      toset(keys(output.nat_eip_allocation_ids)) == toset(["us-east-1a/eipalloc-a", "us-east-1b/eipalloc-b"]) &&
      length(output.regional_nat_gateway_addresses_by_az["us-east-1a"]) == 1 &&
      length(output.regional_nat_gateway_addresses_by_az["us-east-1b"]) == 1 &&
      length(output.nat_private_ips) == 0
    )
    error_message = "Regional Tier 1 outputs must preserve all address records, managed route-table ID, and the no-private-IP sentinel."
  }
}

run "regional_existing_eips_manual_mode" {
  command = plan

  variables {
    vpc                = { name = "regional-manual" }
    addressing         = { primary = { cidr_block = "10.1.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.1.0.0/24", "us-east-1b" = "10.1.1.0/24" } }
        routing = { nat_gateway = true }
      }
    }
    nat_gateway = {
      mode = "regional"
      eip = {
        mode = "existing"
        allocation_ids = {
          us-east-1a = "eipalloc-existing-a"
          us-east-1b = "eipalloc-existing-b"
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_nat_gateway.main["nat/regional"].availability_zone_address) == 2 &&
      toset([for address in aws_nat_gateway.main["nat/regional"].availability_zone_address : address.availability_zone]) == toset(["us-east-1a", "us-east-1b"]) &&
      toset(flatten([for address in aws_nat_gateway.main["nat/regional"].availability_zone_address : tolist(address.allocation_ids)])) == toset(["eipalloc-existing-a", "eipalloc-existing-b"]) &&
      length(aws_eip.nat) == 0
    )
    error_message = "Regional existing-EIP mode must emit one manual availability_zone_address block per configured AZ without owning EIPs."
  }
}

run "regional_byoip_pool_manual_mode" {
  command = plan

  variables {
    vpc                = { name = "regional-byoip" }
    addressing         = { primary = { cidr_block = "10.2.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.2.0.0/24", "us-east-1b" = "10.2.1.0/24" } }
        routing = { nat_gateway = true }
      }
    }
    nat_gateway = {
      mode = "regional"
      eip = {
        mode             = "byoip_pool"
        public_ipv4_pool = "ipv4pool-ec2-0123456789abcdef0"
      }
    }
  }

  assert {
    condition = (
      length(aws_eip.nat) == 2 &&
      alltrue([for eip in values(aws_eip.nat) : eip.public_ipv4_pool == "ipv4pool-ec2-0123456789abcdef0"]) &&
      length(aws_nat_gateway.main["nat/regional"].availability_zone_address) == 2
    )
    error_message = "Regional BYOIP mode must create one pool-backed EIP per configured AZ and attach them through manual address blocks."
  }
}

run "reject_regional_with_az" {
  command = plan

  variables {
    vpc                = { name = "regional-invalid" }
    addressing         = { primary = { cidr_block = "10.3.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    nat_gateway        = { mode = "regional", az = "us-east-1a" }
  }

  expect_failures = [var.nat_gateway]
}

run "reject_regional_with_subnet_group" {
  command = plan

  variables {
    vpc                = { name = "regional-invalid" }
    addressing         = { primary = { cidr_block = "10.4.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      public = { role = "public", ipv4 = { cidrs_by_az = { "us-east-1a" = "10.4.0.0/24" } } }
    }
    nat_gateway = { mode = "regional", subnet_group = "public" }
  }

  expect_failures = [var.nat_gateway]
}

run "reject_regional_private_nat" {
  command = plan

  variables {
    vpc                = { name = "regional-invalid" }
    addressing         = { primary = { cidr_block = "10.5.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    nat_gateway        = { mode = "regional", connectivity_type = "private" }
  }

  expect_failures = [var.nat_gateway]
}
