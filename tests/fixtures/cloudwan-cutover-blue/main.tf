terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29"
    }
  }
}

module "vpc" {
  source = "../../.."

  vpc                = { name = "cwan-cutover" }
  addressing         = { primary = { cidr_block = "10.98.0.0/16" }, secondary = { ipv6 = { ipv6 = { amazon_assigned = true } } } }
  availability_zones = { names = ["us-east-1a"] }
  subnets = {
    attachment = {
      role = "core_network"
      ipv4 = { cidrs_by_az = { us-east-1a = "10.98.0.0/28" } }
      ipv6 = { secondary_cidr_key = "ipv6", auto_assign = true, cidr_index = 0 }
    }
    workload = {
      role = "private"
      ipv4 = { cidrs_by_az = { us-east-1a = "10.98.1.0/24" } }
      ipv6 = { secondary_cidr_key = "ipv6", auto_assign = true, cidr_index = 1 }
      routing = {
        core_network_attachments      = { blue = ["10.0.0.0/8", "pl-0123456789abcdef0"] }
        core_network_attachments_ipv6 = { blue = ["2001:db8:100::/48", "pl-1123456789abcdef0"] }
      }
    }
  }
  core_network_attachments = {
    blue = {
      subnet_group = "attachment"
      id           = "core-network-0123456789abcdef0"
    }
    green = {
      subnet_group = "attachment"
      id           = "core-network-1123456789abcdef0"
    }
  }
}

output "route_ids" {
  description = "Physical route IDs by destination across IPv4, IPv6 and prefix lists."
  value = {
    for route in concat(values(module.vpc.resources.routes.cwan_attachment), values(module.vpc.resources.routes.cwan_attachment_ipv6)) :
    coalesce(route.destination_cidr_block, route.destination_ipv6_cidr_block, route.destination_prefix_list_id) => route.id
  }
}

output "attachment_ids" {
  description = "Attachment IDs before and after route cutover."
  value       = module.vpc.core_network_attachment_ids
}

output "route_targets" {
  description = "Core Network ARNs selected by routes."
  value       = distinct([for route in concat(values(module.vpc.resources.routes.cwan_attachment), values(module.vpc.resources.routes.cwan_attachment_ipv6)) : route.core_network_arn])
}
