mock_provider "aws" {
  override_during = plan

  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { region = "us-east-1" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.98.0.0/16"
    }
  }
  mock_resource "aws_subnet" {
    defaults = {
      id  = "subnet-mock"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
    }
  }
  mock_resource "aws_networkmanager_vpc_attachment" {
    defaults = { id = "attachment-created" }
  }
  mock_resource "aws_networkmanager_attachment_accepter" {
    defaults = { id = "accepter-created" }
  }
}

run "create_attachment_create_accepter" {
  command = plan
  variables {
    vpc                = { name = "cwan-create-create" }
    addressing         = { primary = { cidr_block = "10.98.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      cwan = {
        role = "core_network"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.98.0.0/28" } }
        core_network_options = {
          id                 = "cnet-0123456789abcdef0"
          arn                = "arn:aws:networkmanager::123456789012:core-network/cnet-0123456789abcdef0"
          create             = true
          require_acceptance = true
          accept_attachment  = true
          create_accepter    = true
        }
      }
    }
  }
  assert {
    condition     = length(aws_networkmanager_vpc_attachment.this) == 1 && length(aws_networkmanager_attachment_accepter.this) == 1 && aws_networkmanager_attachment_accepter.this["vpc"].attachment_id == "attachment-created"
    error_message = "Created attachment/create accepter must use the effective created attachment ID."
  }
}

run "create_attachment_inject_accepter" {
  command = plan
  variables {
    vpc                = { name = "cwan-create-inject" }
    addressing         = { primary = { cidr_block = "10.98.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      cwan = {
        role = "core_network"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.98.0.0/28" } }
        core_network_options = {
          id                 = "cnet-0123456789abcdef0"
          arn                = "arn:aws:networkmanager::123456789012:core-network/cnet-0123456789abcdef0"
          create             = true
          require_acceptance = true
          accept_attachment  = true
          create_accepter    = false
          accepter_id        = "accepter-injected"
        }
      }
    }
  }
  assert {
    condition     = length(aws_networkmanager_vpc_attachment.this) == 1 && length(aws_networkmanager_attachment_accepter.this) == 0 && output.core_network_attachment_accepter_id == "accepter-injected"
    error_message = "Created attachment/injected accepter must create only the attachment and return the injected accepter ID."
  }
}

run "inject_attachment_create_accepter" {
  command = plan
  variables {
    vpc                = { name = "cwan-inject-create" }
    addressing         = { primary = { cidr_block = "10.98.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      cwan = {
        role = "core_network"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.98.0.0/28" } }
        core_network_options = {
          id                 = "cnet-0123456789abcdef0"
          arn                = "arn:aws:networkmanager::123456789012:core-network/cnet-0123456789abcdef0"
          create             = false
          attachment_id      = "attachment-injected"
          require_acceptance = true
          accept_attachment  = true
          create_accepter    = true
        }
      }
    }
  }
  assert {
    condition     = length(aws_networkmanager_vpc_attachment.this) == 0 && length(aws_networkmanager_attachment_accepter.this) == 1 && aws_networkmanager_attachment_accepter.this["vpc"].attachment_id == "attachment-injected"
    error_message = "Injected attachment/create accepter must materialize the accepter against the effective injected attachment ID."
  }
}

run "inject_attachment_inject_accepter" {
  command = plan
  variables {
    vpc                = { name = "cwan-inject-inject" }
    addressing         = { primary = { cidr_block = "10.98.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      cwan = {
        role = "core_network"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.98.0.0/28" } }
        core_network_options = {
          id                 = "cnet-0123456789abcdef0"
          arn                = "arn:aws:networkmanager::123456789012:core-network/cnet-0123456789abcdef0"
          create             = false
          attachment_id      = "attachment-injected"
          require_acceptance = true
          accept_attachment  = true
          create_accepter    = false
          accepter_id        = "accepter-injected"
        }
      }
    }
  }
  assert {
    condition     = length(aws_networkmanager_vpc_attachment.this) == 0 && length(aws_networkmanager_attachment_accepter.this) == 0 && output.core_network_attachment_id == "attachment-injected" && output.core_network_attachment_accepter_id == "accepter-injected"
    error_message = "Fully injected Cloud WAN ownership must create neither resource and return both effective IDs."
  }
}

run "reject_accept_attachment_without_required_acceptance" {
  command = plan
  variables {
    vpc                = { name = "cwan-invalid-acceptance" }
    addressing         = { primary = { cidr_block = "10.98.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      cwan = {
        role = "core_network"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.98.0.0/28" } }
        core_network_options = {
          id                 = "cnet-0123456789abcdef0"
          create             = false
          attachment_id      = "attachment-documentation"
          require_acceptance = false
          accept_attachment  = true
          create_accepter    = false
          accepter_id        = "accepter-documentation"
        }
      }
    }
  }

  expect_failures = [var.subnets]
}
