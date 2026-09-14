terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29"
    }
  }
}

# terraform_data.output stays unknown during plan, unlike plan-time AWS mocks.
resource "terraform_data" "identity" {
  input = {
    vpc_id         = "vpc-computed"
    network_id     = "core-network-0123456789abcdef0"
    network_arn    = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
    attachment_id  = "attachment-computed"
    accepter_id    = "accepter-computed"
    route_table_id = "rtb-computed-shared"
  }
}

module "vpc" {
  source = "../../.."

  vpc = {
    name   = "computed-cwan"
    create = false
    id     = terraform_data.identity.output.vpc_id
  }
  addressing         = { primary = {} }
  availability_zones = { names = ["us-east-1a"] }
  subnets = {
    attachment = {
      role = "core_network"
      ipv4 = { cidrs_by_az = { us-east-1a = "10.98.0.0/28" } }
    }
    workload = {
      role               = "private"
      ipv4               = { cidrs_by_az = { us-east-1a = "10.98.1.0/24" } }
      manage_route_table = false
      route_table_key    = "workload"
      route_table_id     = terraform_data.identity.output.route_table_id
      routing = { core_network_attachments = {
        created  = ["10.0.0.0/8"]
        injected = ["172.16.0.0/12"]
      } }
    }
    isolated = {
      role                                     = "isolated"
      ipv4                                     = { cidrs_by_az = { us-east-1a = "10.98.2.0/24" } }
      manage_route_table                       = false
      route_table_key                          = "isolated"
      route_table_id                           = terraform_data.identity.output.route_table_id
      isolated_accepts_uninspected_route_table = true
    }
  }
  core_network_attachments = {
    created = {
      subnet_group = "attachment"
      id           = terraform_data.identity.output.network_id
      arn          = terraform_data.identity.output.network_arn
    }
    injected = {
      subnet_group       = "attachment"
      id                 = "core-network-1123456789abcdef0"
      create             = false
      attachment_id      = terraform_data.identity.output.attachment_id
      require_acceptance = true
      accept_attachment  = true
      create_accepter    = false
      accepter_id        = terraform_data.identity.output.accepter_id
    }
  }
}

output "keys" {
  description = "Plan-known attachment, acceptance and route identities."
  value = {
    attachments  = keys(module.vpc.core_network_attachment_ids)
    created      = keys(module.vpc.resources.core_network_attachments)
    accepters    = keys(module.vpc.core_network_attachment_accepter_ids)
    readiness    = keys(module.vpc.resources.core_network_readiness)
    routes       = keys(module.vpc.resources.routes.cwan_attachment)
    route_tables = keys(module.vpc.resources.injected_route_table_ids)
  }
}
