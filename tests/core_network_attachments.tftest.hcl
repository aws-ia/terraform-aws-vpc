mock_provider "aws" {
  override_during = plan

  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { region = "us-east-1" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_resource "aws_vpc" {
    defaults = {
      id              = "vpc-mock"
      arn             = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block      = "10.98.0.0/16"
      ipv6_cidr_block = "2001:db8::/56"
    }
  }
  mock_resource "aws_subnet" {
    defaults = {
      id  = "subnet-mock"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
    }
  }
  mock_resource "aws_vpc_ipv6_cidr_block_association" {
    defaults = { ipv6_cidr_block = "2001:db8::/56" }
  }
  mock_resource "aws_networkmanager_vpc_attachment" {
    defaults = { id = "attachment-created" }
  }
  mock_resource "aws_networkmanager_attachment_accepter" {
    defaults = { id = "accepter-created" }
  }
}

variables {
  vpc = { name = "multi-cwan" }
  addressing = {
    primary   = { cidr_block = "10.98.0.0/16" }
    secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } }
  }
  availability_zones = { names = ["us-east-1a"] }
  subnets = {
    blue = {
      role = "core_network"
      ipv4 = { cidrs_by_az = { us-east-1a = "10.98.0.0/28" } }
    }
    green = {
      role = "core_network"
      ipv4 = { cidrs_by_az = { us-east-1a = "10.98.0.16/28" } }
      ipv6 = { secondary_cidr_key = "ipv6", cidrs_by_az = { us-east-1a = "2001:db8:0:1::/64" } }
      tags = { segment = "subnet-default", tier = "network" }
    }
    workload = {
      role = "private"
      ipv4 = { cidrs_by_az = { us-east-1a = "10.98.1.0/24" } }
      ipv6 = { secondary_cidr_key = "ipv6", cidrs_by_az = { us-east-1a = "2001:db8:0:2::/64" } }
      routing = {
        core_network_attachments = {
          blue  = ["10.0.0.0/8", "pl-0123456789abcdef0"]
          green = ["172.16.0.0/12"]
        }
        core_network_attachments_ipv6 = { green = ["2001:db8:100::/48", "pl-1123456789abcdef0"] }
      }
    }
  }
  core_network_attachments = {
    blue = {
      subnet_group = "blue"
      id           = "core-network-0123456789abcdef0"
      arn          = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
      tags         = { segment = "blue" }
    }
    green = {
      subnet_group               = "green"
      id                         = "core-network-1123456789abcdef0"
      arn                        = "arn:aws:networkmanager::123456789012:core-network/core-network-1123456789abcdef0"
      appliance_mode             = true
      dns_support                = false
      security_group_referencing = true
      routing_policy_label       = "green-policy"
      require_acceptance         = true
      accept_attachment          = true
      tags                       = { segment = "green" }
    }
  }
}

run "two_attachments_with_independent_routes" {
  command = plan

  assert {
    condition     = toset(keys(aws_networkmanager_vpc_attachment.this)) == toset(["blue", "green"])
    error_message = "A VPC must support two independently keyed Cloud WAN attachments."
  }

  assert {
    condition = (
      length(aws_route.cwan_attachment) == 3 && length(aws_route.cwan_attachment_ipv6) == 2 &&
      aws_route.cwan_attachment["workload/us-east-1a/cwan/blue/10.0.0.0-8"].core_network_arn == var.core_network_attachments.blue.arn &&
      aws_route.cwan_attachment["workload/us-east-1a/cwan/green/172.16.0.0-12"].core_network_arn == var.core_network_attachments.green.arn &&
      aws_route.cwan_attachment["workload/us-east-1a/cwan/blue/pl-0123456789abcdef0"].destination_prefix_list_id == "pl-0123456789abcdef0" &&
      aws_route.cwan_attachment_ipv6["workload/us-east-1a/cwan6/green/2001:db8:100::-48"].destination_ipv6_cidr_block == "2001:db8:100::/48" &&
      aws_route.cwan_attachment_ipv6["workload/us-east-1a/cwan6/green/pl-1123456789abcdef0"].destination_prefix_list_id == "pl-1123456789abcdef0" &&
      alltrue([for route in values(aws_route.cwan_attachment_ipv6) : route.core_network_arn == var.core_network_attachments.green.arn]) &&
      output.subnet_connectivity_by_group_by_az.workload["us-east-1a"].core_network
    )
    error_message = "IPv4, IPv6 and prefix-list routes must select their own attachment ARN and report Cloud WAN connectivity."
  }

  assert {
    condition = (
      aws_networkmanager_vpc_attachment.this["blue"].core_network_id == var.core_network_attachments.blue.id &&
      aws_networkmanager_vpc_attachment.this["green"].core_network_id == var.core_network_attachments.green.id &&
      aws_networkmanager_vpc_attachment.this["green"].subnet_arns == toset([aws_subnet.main["green/us-east-1a"].arn]) &&
      one(aws_networkmanager_vpc_attachment.this["green"].options).appliance_mode_support &&
      one(aws_networkmanager_vpc_attachment.this["green"].options).ipv6_support &&
      !one(aws_networkmanager_vpc_attachment.this["blue"].options).ipv6_support &&
      !one(aws_networkmanager_vpc_attachment.this["green"].options).dns_support &&
      one(aws_networkmanager_vpc_attachment.this["green"].options).security_group_referencing_support &&
      aws_networkmanager_vpc_attachment.this["green"].routing_policy_label == "green-policy" &&
      aws_networkmanager_vpc_attachment.this["green"].tags.segment == "green" &&
      aws_networkmanager_vpc_attachment.this["green"].tags.tier == "network" &&
      aws_networkmanager_vpc_attachment.this["blue"].tags.Name == "multi-cwan-core-network-attachment-blue" &&
      toset(keys(aws_networkmanager_attachment_accepter.this)) == toset(["green"]) &&
      toset(keys(terraform_data.core_network_readiness)) == toset(["blue", "green"]) &&
      output.core_network_attachment_ids == { blue = "attachment-created", green = "attachment-created" } &&
      output.core_network_attachment_accepter_ids == { green = "accepter-created" } &&
      output.core_network_attachment_id == null && output.core_network_attachment_accepter_id == null &&
      output.core_network_attachment == null
    )
    error_message = "Attachments must retain per-key options, subnet selection, tags, acceptance and plural outputs; ambiguous legacy outputs must be null."
  }
}

run "all_attachment_and_accepter_ownership_combinations" {
  command = plan
  variables {
    subnets = { blue = var.subnets.blue }
    core_network_attachments = {
      for index, key in ["create_create", "create_inject", "inject_create", "inject_inject"] : key => {
        subnet_group       = "blue"
        id                 = "core-network-${index}123456789abcdef0"
        create             = index < 2
        attachment_id      = index < 2 ? null : "attachment-${key}"
        require_acceptance = true
        accept_attachment  = true
        create_accepter    = index % 2 == 0
        accepter_id        = index % 2 == 0 ? null : "accepter-${key}"
      }
    }
  }
  assert {
    condition = (
      toset(keys(aws_networkmanager_vpc_attachment.this)) == toset(["create_create", "create_inject"]) &&
      toset(keys(aws_networkmanager_attachment_accepter.this)) == toset(["create_create", "inject_create"]) &&
      aws_networkmanager_attachment_accepter.this["inject_create"].attachment_id == "attachment-inject_create" &&
      aws_networkmanager_attachment_accepter.this["create_create"].attachment_id == "attachment-created" &&
      output.core_network_attachment_ids.inject_inject == "attachment-inject_inject" &&
      output.core_network_attachment_accepter_ids.create_inject == "accepter-create_inject" &&
      output.core_network_attachment_accepter_ids.inject_inject == "accepter-inject_inject"
    )
    error_message = "Every attachment must independently create or inject its attachment and accepter, even when subnets are reused."
  }
}

run "pending_attachment_does_not_block_unrelated_routes" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { routing = { core_network_attachments = { blue = ["10.0.0.0/8"], green = [] } } })
    })
    core_network_attachments = merge(var.core_network_attachments, {
      green = merge(var.core_network_attachments.green, { accept_attachment = false })
    })
  }
  assert {
    condition     = toset(keys(terraform_data.core_network_readiness)) == toset(["blue"]) && length(aws_route.cwan_attachment) == 1
    error_message = "External acceptance of an unrouted attachment must not block existing routes."
  }
}

run "five_attachments_are_supported" {
  command = plan
  variables {
    subnets = { blue = var.subnets.blue }
    core_network_attachments = {
      for index in range(5) : "network-${index}" => {
        subnet_group = "blue"
        id           = "core-network-${index}123456789abcdef0"
      }
    }
  }
  assert {
    condition     = length(aws_networkmanager_vpc_attachment.this) == 5
    error_message = "The documented AWS quota of five attachments per VPC must be supported."
  }
}

run "reject_six_attachments" {
  command = plan
  variables {
    subnets = { blue = var.subnets.blue }
    core_network_attachments = {
      for index in range(6) : "network-${index}" => {
        subnet_group = "blue"
        id           = "core-network-${index}123456789abcdef0"
      }
    }
  }
  expect_failures = [var.core_network_attachments]
}

run "reject_mixed_attachment_forms" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      blue = merge(var.subnets.blue, { core_network_options = { id = var.core_network_attachments.blue.id } })
    })
  }
  expect_failures = [terraform_data.attachment_contract_validation]
}

run "reject_multiple_legacy_adapters" {
  command = plan
  variables {
    core_network_attachments = {}
    subnets = {
      for key in ["blue", "green"] : key => merge(var.subnets[key], { core_network_options = { id = var.core_network_attachments[key].id } })
    }
  }
  expect_failures = [var.subnets]
}

run "reject_unknown_subnet_group" {
  command = plan
  variables {
    core_network_attachments = merge(var.core_network_attachments, {
      green = merge(var.core_network_attachments.green, { subnet_group = "missing" })
    })
  }
  expect_failures = [terraform_data.attachment_contract_validation]
}

run "reject_wrong_subnet_role" {
  command = plan
  variables {
    core_network_attachments = merge(var.core_network_attachments, {
      green = merge(var.core_network_attachments.green, { subnet_group = "workload" })
    })
  }
  expect_failures = [terraform_data.attachment_contract_validation]
}

run "reject_unknown_route_key" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { routing = { core_network_attachments = { missing = ["10.0.0.0/8"] } } })
    })
  }
  expect_failures = [terraform_data.attachment_contract_validation]
}

run "reject_ambiguous_singular_routes" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { routing = { core_network = ["10.0.0.0/8"] } })
    })
  }
  expect_failures = [terraform_data.attachment_contract_validation]
}

run "reject_routes_pending_external_acceptance" {
  command = plan
  variables {
    core_network_attachments = merge(var.core_network_attachments, {
      green = merge(var.core_network_attachments.green, { accept_attachment = false })
    })
  }
  expect_failures = [terraform_data.attachment_contract_validation]
}

run "reject_cross_account_managed_acceptance" {
  command = plan
  variables {
    core_network_attachments = merge(var.core_network_attachments, {
      green = merge(var.core_network_attachments.green, { arn = "arn:aws:networkmanager::999999999999:core-network/core-network-1123456789abcdef0" })
    })
  }
  expect_failures = [terraform_data.attachment_contract_validation]
}

run "reject_mismatched_arn" {
  command = plan
  variables {
    core_network_attachments = merge(var.core_network_attachments, {
      green = merge(var.core_network_attachments.green, { arn = var.core_network_attachments.blue.arn })
    })
  }
  expect_failures = [terraform_data.attachment_contract_validation]
}

run "reject_duplicate_route_destinations" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { routing = { core_network_attachments = { blue = ["10.0.0.0/8"], green = ["10.0.0.0/8"] } } })
    })
  }
  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_isolated_cloud_wan_routes" {
  command = plan
  variables {
    subnets = merge(var.subnets, { workload = merge(var.subnets.workload, { role = "isolated" }) })
  }
  expect_failures = [var.subnets]
}

run "reject_invalid_ipv4_destination" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { routing = { core_network_attachments = { blue = ["not-a-cidr"] } } })
    })
  }
  expect_failures = [var.subnets]
}

run "reject_ipv4_in_ipv6_routes" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { routing = { core_network_attachments_ipv6 = { blue = ["10.0.0.0/8"] } } })
    })
  }
  expect_failures = [var.subnets]
}

run "legacy_adapter_preserves_resource_and_route_identity" {
  command = plan
  variables {
    core_network_attachments = {}
    subnets = {
      blue = merge(var.subnets.blue, { core_network_options = {
        id                 = var.core_network_attachments.blue.id
        require_acceptance = true
        accept_attachment  = true
      } })
      workload = merge(var.subnets.workload, { routing = {
        core_network      = ["10.0.0.0/8"]
        core_network_ipv6 = ["2001:db8:100::/48"]
      } })
    }
  }
  assert {
    condition = (
      toset(keys(aws_networkmanager_vpc_attachment.this)) == toset(["vpc"]) &&
      toset(keys(aws_networkmanager_attachment_accepter.this)) == toset(["vpc"]) &&
      toset(keys(terraform_data.core_network_readiness)) == toset(["vpc"]) &&
      toset(keys(aws_route.cwan)) == toset(["workload/us-east-1a/cwan/10.0.0.0-8"]) &&
      toset(keys(aws_route.cwan_ipv6)) == toset(["workload/us-east-1a/cwan6/2001:db8:100::-48"]) &&
      aws_networkmanager_vpc_attachment.this["vpc"].tags.Name == "multi-cwan-core-network-attachment" &&
      aws_route.cwan["workload/us-east-1a/cwan/10.0.0.0-8"].core_network_arn == "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0" &&
      output.core_network_attachment_id == "attachment-created" &&
      output.core_network_attachment_accepter_id == "accepter-created" &&
      output.core_network_attachment.id == "attachment-created" &&
      output.core_network_attachment_ids == { vpc = "attachment-created" }
    )
    error_message = "The compatibility adapter must preserve attachment/accepter/readiness keys, route addresses, Name tags and scalar/full outputs."
  }
}

run "single_plural_attachment_accepts_legacy_routes" {
  command = plan
  variables {
    core_network_attachments = { vpc = var.core_network_attachments.blue }
    subnets = {
      blue = var.subnets.blue
      workload = merge(var.subnets.workload, { routing = {
        core_network = ["10.0.0.0/8"]
      } })
    }
  }
  assert {
    condition = (
      output.core_network_attachment_id == "attachment-created" &&
      output.core_network_attachment_accepter_id == null &&
      output.core_network_attachment == null &&
      aws_route.cwan["workload/us-east-1a/cwan/10.0.0.0-8"].core_network_arn == var.core_network_attachments.vpc.arn
    )
    error_message = "A single plural attachment may use singular routes and scalar IDs; the v4 full-object output belongs only to the embedded adapter."
  }
}

run "shared_route_tables_deduplicate_matching_routes" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { manage_route_table = false, route_table_key = "shared", route_table_id = "rtb-shared" })
      other = merge(var.subnets.workload, {
        ipv4               = { cidrs_by_az = { us-east-1a = "10.98.2.0/24" } }
        ipv6               = { secondary_cidr_key = "ipv6", cidrs_by_az = { us-east-1a = "2001:db8:0:3::/64" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-shared"
      })
    })
  }
  assert {
    condition = (
      length(aws_route.cwan_attachment) == 3 && length(aws_route.cwan_attachment_ipv6) == 2 &&
      alltrue([for route in values(aws_route.cwan_attachment) : route.route_table_id == "rtb-shared"]) &&
      contains(keys(aws_route.cwan_attachment), "injected/shared/cwan/green/172.16.0.0-12")
    )
    error_message = "Shared tables must merge keyed Cloud WAN destinations without creating duplicate AWS routes."
  }
}

run "reject_conflicting_routes_on_shared_table" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, {
        manage_route_table = false, route_table_key = "shared", route_table_id = "rtb-shared"
        routing            = { core_network_attachments = { blue = ["10.0.0.0/8"] } }
      })
      other = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.98.2.0/24" } }
        manage_route_table = false, route_table_key = "shared", route_table_id = "rtb-shared"
        routing            = { core_network_attachments = { green = ["10.0.0.0/8"] } }
      }
    })
  }
  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_duplicate_singular_and_keyed_route" {
  command = plan
  variables {
    core_network_attachments = { blue = var.core_network_attachments.blue }
    subnets = {
      blue = var.subnets.blue
      workload = merge(var.subnets.workload, { routing = {
        core_network             = ["10.0.0.0/8"]
        core_network_attachments = { blue = ["10.0.0.0/8"] }
      } })
    }
  }
  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_duplicate_prefix_list_across_address_families" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { routing = {
        core_network_attachments      = { blue = ["pl-0123456789abcdef0"] }
        core_network_attachments_ipv6 = { blue = ["pl-0123456789abcdef0"] }
      } })
    })
  }
  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_duplicate_destinations_in_one_list" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { routing = {
        core_network_attachments = { blue = ["10.0.0.0/8", "10.0.0.0/8"] }
      } })
    })
  }
  expect_failures = [var.subnets]
}

run "reject_injected_attachment_without_id" {
  command = plan
  variables {
    core_network_attachments = merge(var.core_network_attachments, {
      blue = merge(var.core_network_attachments.blue, { create = false })
    })
  }
  expect_failures = [var.core_network_attachments]
}

run "reject_injected_accepter_without_id" {
  command = plan
  variables {
    core_network_attachments = merge(var.core_network_attachments, {
      green = merge(var.core_network_attachments.green, { create_accepter = false })
    })
  }
  expect_failures = [var.core_network_attachments]
}

run "reject_acceptance_without_required_acceptance" {
  command = plan
  variables {
    core_network_attachments = merge(var.core_network_attachments, {
      green = merge(var.core_network_attachments.green, { require_acceptance = false })
    })
  }
  expect_failures = [var.core_network_attachments]
}

run "reject_equivalent_ipv6_destinations_for_two_attachments" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { routing = {
        core_network_attachments_ipv6 = {
          blue  = ["2001:db8::/48"]
          green = ["2001:0db8:0000::/48"]
        }
      } })
    })
  }
  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "equivalent_cidrs_share_one_key_per_attachment" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, { routing = {
        core_network_attachments_ipv6 = { green = ["2001:db8::/48", "2001:0db8:0000::/48"] }
      } })
    })
  }
  assert {
    condition = (
      toset(keys(aws_route.cwan_attachment_ipv6)) == toset(["workload/us-east-1a/cwan6/green/2001:db8::-48"]) &&
      aws_route.cwan_attachment_ipv6["workload/us-east-1a/cwan6/green/2001:db8::-48"].destination_ipv6_cidr_block == "2001:db8::/48"
    )
    error_message = "Equivalent CIDR spellings must resolve to one physical route and stable state key."
  }
}

run "reject_equivalent_cidrs_across_shared_table_groups" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, {
        manage_route_table = false, route_table_key = "shared", route_table_id = "rtb-shared"
        routing            = { core_network_attachments_ipv6 = { blue = ["2001:db8::/48"] } }
      })
      other = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.98.2.0/24" } }
        manage_route_table = false, route_table_key = "shared", route_table_id = "rtb-shared"
        routing            = { core_network_attachments_ipv6 = { green = ["2001:0db8:0000::/48"] } }
      }
    })
  }
  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_equivalent_cidr_on_generic_route_surface" {
  command = plan
  variables {
    subnets = merge(var.subnets, {
      workload = merge(var.subnets.workload, {
        routing = { core_network_attachments_ipv6 = { blue = ["2001:db8::/48"] } }
        routes = {
          peer = {
            destination = { type = "ipv6_cidr", value = "2001:0db8:0000::/48" }
            target      = { type = "vpc_peering", id = "pcx-documentation" }
          }
        }
      })
    })
  }
  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}
