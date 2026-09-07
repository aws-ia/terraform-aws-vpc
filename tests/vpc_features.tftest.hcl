mock_provider "aws" {
  override_during = plan
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

  mock_resource "aws_vpc_block_public_access_options" {
    defaults = { id = "vpc-bpa-options-mock" }
  }

  mock_resource "aws_vpc_block_public_access_exclusion" {
    defaults = { id = "vpc-bpa-exclusion-mock" }
  }

  mock_resource "aws_vpc_dhcp_options" {
    defaults = { id = "dopt-mock" }
  }
}

run "create_bpa_and_dhcp_options" {
  command = plan

  variables {
    vpc                = { name = "feature-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
      }
    }
    vpc_block_public_access = {
      enabled                     = true
      internet_gateway_block_mode = "block-bidirectional"
      exclusions = {
        application-egress = {
          internet_gateway_exclusion_mode = "allow-egress"
          target                          = "subnet"
          subnet_key                      = "app/us-east-1a"
        }
        vpc-break-glass = {
          internet_gateway_exclusion_mode = "allow-bidirectional"
        }
      }
    }
    dhcp_options = {
      enabled                           = true
      domain_name                       = "corp.example.internal"
      domain_name_servers               = ["AmazonProvidedDNS"]
      ntp_servers                       = ["169.254.169.123"]
      netbios_node_type                 = 2
      ipv6_address_preferred_lease_time = "140"
    }
  }

  assert {
    condition = (
      aws_vpc_block_public_access_options.this[0].internet_gateway_block_mode == "block-bidirectional" &&
      aws_vpc_block_public_access_exclusion.this["application-egress"].internet_gateway_exclusion_mode == "allow-egress" &&
      aws_vpc_block_public_access_exclusion.this["application-egress"].subnet_id == "subnet-mock" &&
      aws_vpc_block_public_access_exclusion.this["vpc-break-glass"].vpc_id == "vpc-mock" &&
      toset(keys(output.vpc_block_public_access_exclusion_ids)) == toset(["application-egress", "vpc-break-glass"])
    )
    error_message = "BPA options/exclusions must plan the declared regional mode and stable VPC/subnet targets."
  }

  assert {
    condition = (
      aws_vpc_dhcp_options.this[0].domain_name == "corp.example.internal" &&
      aws_vpc_dhcp_options.this[0].domain_name_servers == tolist(["AmazonProvidedDNS"]) &&
      aws_vpc_dhcp_options.this[0].ntp_servers == tolist(["169.254.169.123"]) &&
      aws_vpc_dhcp_options_association.this[0].dhcp_options_id == "dopt-mock" &&
      output.dhcp_options_id == "dopt-mock"
    )
    error_message = "Typed DHCP options and their VPC association must retain planned attributes."
  }
}

run "inject_bpa_and_dhcp_options" {
  command = plan

  variables {
    vpc                = { name = "feature-inject-test" }
    addressing         = { primary = { cidr_block = "10.1.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    vpc_block_public_access = {
      enabled                     = true
      create                      = false
      id                          = "vpc-bpa-options-existing"
      internet_gateway_block_mode = "block-ingress"
      exclusions = {
        existing = {
          create = false
          id     = "vpc-bpa-exclusion-existing"
        }
      }
    }
    dhcp_options = {
      enabled = true
      create  = false
      id      = "dopt-0123456789abcdef0"
    }
  }

  assert {
    condition = (
      length(aws_vpc_block_public_access_options.this) == 0 &&
      length(aws_vpc_block_public_access_exclusion.this) == 0 &&
      output.vpc_block_public_access_options_id == "vpc-bpa-options-existing" &&
      output.vpc_block_public_access_exclusion_ids.existing == "vpc-bpa-exclusion-existing" &&
      length(aws_vpc_dhcp_options.this) == 0 &&
      aws_vpc_dhcp_options_association.this[0].dhcp_options_id == "dopt-0123456789abcdef0"
    )
    error_message = "BPA and DHCP injection must omit owned resources while preserving typed IDs and the DHCP association."
  }
}

run "reject_bpa_allow_egress_under_ingress_mode" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.2.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    vpc_block_public_access = {
      enabled                     = true
      internet_gateway_block_mode = "block-ingress"
      exclusions = {
        invalid = { internet_gateway_exclusion_mode = "allow-egress" }
      }
    }
  }

  expect_failures = [var.vpc_block_public_access]
}

run "reject_invalid_dhcp_node_type" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.3.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    dhcp_options = {
      enabled           = true
      netbios_node_type = 3
    }
  }

  expect_failures = [var.dhcp_options]
}
