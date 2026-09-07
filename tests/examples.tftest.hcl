mock_provider "aws" {
  override_during = plan

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

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
      id                        = "vpc-mock"
      arn                       = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block                = "10.0.0.0/16"
      ipv6_cidr_block           = "2001:db8:4200::/56"
      default_security_group_id = "sg-default"
      default_network_acl_id    = "acl-default"
      default_route_table_id    = "rtb-default"
      main_route_table_id       = "rtb-default"
    }
  }

  mock_resource "aws_vpc_ipv6_cidr_block_association" {
    defaults = {
      id              = "vpc-cidr-assoc-mock"
      ipv6_cidr_block = "2001:db8:4200::/56"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.80.0.0/16"
    }
  }

  mock_data "aws_security_group" {
    defaults = { id = "sg-default" }
  }

  mock_data "aws_network_acls" {
    defaults = { ids = ["acl-default"] }
  }

  mock_data "aws_route_table" {
    defaults = { id = "rtb-default" }
  }

  mock_resource "aws_subnet" {
    defaults = {
      id              = "subnet-mock"
      arn             = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
      ipv6_cidr_block = ""
    }
  }

  mock_resource "aws_vpclattice_service_network" {
    defaults = { id = "sn-mock" }
  }

  mock_resource "aws_ec2_transit_gateway" {
    defaults = {
      id  = "tgw-0123456789abcdef0"
      arn = "arn:aws:ec2:us-east-1:123456789012:transit-gateway/tgw-0123456789abcdef0"
    }
  }

  mock_resource "aws_ec2_transit_gateway_route_table" {
    defaults = { id = "tgw-rtb-0123456789abcdef0" }
  }

  mock_resource "aws_ec2_transit_gateway_vpc_attachment" {
    defaults = { id = "tgw-attach-0123456789abcdef0" }
  }

  mock_resource "aws_security_group" {
    defaults = { id = "sg-0123456789abcdef0" }
  }

  mock_resource "aws_vpc_endpoint" {
    defaults = {
      id  = "vpce-0123456789abcdef0"
      arn = "arn:aws:ec2:us-east-1:123456789012:vpc-endpoint/vpce-0123456789abcdef0"
    }
  }

  mock_resource "aws_route53profiles_profile" {
    defaults = {
      id  = "rp-0123456789abcdef0"
      arn = "arn:aws:route53profiles:us-east-1:123456789012:profile/rp-0123456789abcdef0"
    }
  }

  mock_resource "aws_route53_resolver_endpoint" {
    defaults = {
      id  = "rslvr-out-0123456789abcdef0"
      arn = "arn:aws:route53resolver:us-east-1:123456789012:resolver-endpoint/rslvr-out-0123456789abcdef0"
    }
  }

  mock_resource "aws_route53_resolver_rule" {
    defaults = {
      id  = "rslvr-rr-0123456789abcdef0"
      arn = "arn:aws:route53resolver:us-east-1:123456789012:resolver-rule/rslvr-rr-0123456789abcdef0"
    }
  }

  mock_resource "aws_ram_resource_share" {
    defaults = {
      id  = "rs-0123456789abcdef0"
      arn = "arn:aws:ram:us-east-1:123456789012:resource-share/01234567-89ab-cdef-0123-456789abcdef"
    }
  }
}

run "basic_example" {
  command = plan

  module {
    source = "./examples/basic"
  }

  assert {
    condition = (
      toset(keys(output.subnet_ids)) == toset(["app", "database", "public"]) &&
      length(output.subnet_ids.public) == 3 &&
      alltrue([for cidr in values(output.subnet_ipv6_cidrs.public) : cidr != null && cidr != ""]) &&
      alltrue([for cidr in values(output.subnet_ipv6_cidrs.app) : cidr != null && cidr != ""]) &&
      alltrue([for cidr in values(output.subnet_ipv6_cidrs.database) : cidr == null])
    )
    error_message = "The basic example must select exactly three AZs and plan real dual-stack subnets."
  }

  assert {
    condition = (
      length(output.flow_log_ids) == 1 &&
      toset(keys(output.route_tables)) == toset(["app", "database", "public"]) &&
      toset(keys(output.gateway_endpoints.ids)) == toset(["dynamodb", "s3"]) &&
      output.gateway_endpoints.association_count == 6
    )
    error_message = "The basic example must plan Flow Logs, route tables, and both gateway endpoints across all application AZs."
  }
}

run "enterprise_example" {
  command = plan

  module {
    source = "./examples/enterprise"
  }

  assert {
    condition = (
      toset(keys(output.subnet_ids)) == toset(["application", "data", "endpoints", "public"])
    )
    error_message = "The enterprise example must plan all four documented subnet groups."
  }

  assert {
    condition = (
      length(output.nat_gateway_ids) == 3 &&
      output.nat_gateway_evidence.nat_gateway_count == 1 &&
      output.nat_gateway_evidence.availability_modes == toset(["regional"]) &&
      output.nat_gateway_evidence.managed_eip_count == 0 &&
      output.nat_gateway_evidence.nat_route_count == 3 &&
      length(output.flow_log_ids) == 1 &&
      toset(keys(output.gateway_endpoints.ids)) == toset(["dynamodb", "s3"]) &&
      output.gateway_endpoints.association_count == 18 &&
      toset(keys(output.network_acl_controls.ids)) == toset(["application", "data", "endpoints", "public"]) &&
      output.network_acl_controls.rule_count == 22 &&
      output.network_acl_controls.association_count == 12 &&
      alltrue([for cidr in values(output.subnet_ipv6_cidrs.public) : cidr != null && cidr != ""]) &&
      alltrue([for cidr in values(output.subnet_ipv6_cidrs.application) : cidr != null && cidr != ""])
    )
    error_message = "The enterprise example must plan one Regional NAT Gateway, no module-owned EIPs, three NAT routes, one Flow Log, and real dual-stack subnets."
  }
}

run "hub_example" {
  command = plan

  module {
    source = "./examples/hub"
  }

  variables {
    transit_gateway_ids = {
      east = "tgw-0123456789abcdef0"
      west = "tgw-0223456789abcdef0"
    }
    vpc_peering_connection_id = "pcx-0123456789abcdef0"
    gwlb_endpoint_ids_by_az = {
      us-west-2a = "vpce-01111111111111111"
      us-west-2b = "vpce-02222222222222222"
      us-west-2c = "vpce-03333333333333333"
    }
    core_network_id          = "cnet-0123456789abcdef0"
    core_network_arn         = "arn:aws:networkmanager::123456789012:core-network/cnet-0123456789abcdef0"
    flow_log_destination_arn = "arn:aws:firehose:us-west-2:123456789012:deliverystream/network-hub-vpc-flow-logs"
    nat_eip_allocation_ids = {
      us-west-2a = "eipalloc-01111111111111111"
      us-west-2b = "eipalloc-02222222222222222"
      us-west-2c = "eipalloc-03333333333333333"
    }
  }

  assert {
    condition = (
      toset(keys(output.subnet_ids)) == toset(["cwan", "edge", "firewall", "public", "tgw"])
    )
    error_message = "The hub example must plan all five documented subnet groups."
  }

  assert {
    condition = (
      length(output.flow_log_ids) == 1 && length(output.inspection_nat_ids) == 2 &&
      output.public_nat_gateway_evidence.nat_gateway_count == 1 &&
      output.public_nat_gateway_evidence.availability_modes == toset(["regional"]) &&
      output.public_nat_gateway_evidence.managed_eip_count == 0 &&
      output.public_nat_gateway_evidence.nat_route_count == 6 &&
      output.igw_count == 1 && output.generic_route_count == 3 &&
      output.zonal_route_evidence.route_count == 3 &&
      output.zonal_route_evidence.targets_by_az == {
        us-west-2a = "vpce-01111111111111111"
        us-west-2b = "vpce-02222222222222222"
        us-west-2c = "vpce-03333333333333333"
      } &&
      toset(keys(output.transit_gateway_attachment_ids)) == toset(["east", "west"]) &&
      toset(keys(output.route_tables)) == toset(["cwan", "edge", "firewall", "public", "tgw"]) &&
      alltrue(flatten([for group in ["public", "edge", "firewall", "tgw", "cwan"] : [
        for cidr in values(output.subnet_ipv6_cidrs[group]) : cidr != null && cidr != ""
      ]]))
    )
    error_message = "The hub example must plan one public Regional NAT Gateway with injected EIPs, six NAT routes, three AZ-specific GWLB endpoint routes, two private inspection NAT Gateways, and the documented hub resources."
  }
}

run "nat_byoip_example" {
  command = plan

  module {
    source = "./examples/nat_byoip"
  }

  assert {
    condition = (
      toset(keys(output.nat_gateway_ids)) == toset(["byoip_pool", "create", "existing", "regional"]) &&
      alltrue([for ids in values(output.nat_gateway_ids) : length(ids) == 2]) &&
      alltrue([for mode in ["byoip_pool", "create", "existing"] : length(output.nat_eip_allocation_ids[mode]) == 2])
    )
    error_message = "The NAT BYOIP example must plan three two-AZ zonal modes plus one Regional NAT whose ID is repeated across AZ output keys."
  }
}

run "ipam_example" {
  command = plan

  module {
    source = "./examples/ipam"
  }

  assert {
    condition = (
      toset(keys(output.secondary_ipv4_cidr_association_ids)) == toset(["analytics", "legacy"]) &&
      toset(keys(output.secondary_ipv6_cidr_association_ids)) == toset(["ipv6-ipam"]) &&
      toset(keys(output.vpc_ipv6_cidr_blocks)) == toset(["ipv6-ipam"]) &&
      toset(keys(output.subnet_ids)) == toset(["analytics", "application", "ipv6-native", "legacy"]) &&
      alltrue([for subnets in values(output.subnet_ids) : length(subnets) == 2])
    )
    error_message = "The IPAM example must plan primary/IPAM and named secondary addressing across all documented subnet groups."
  }
}

run "dual_stack_example" {
  command = plan

  module {
    source = "./examples/dual_stack"
  }

  assert {
    condition = (
      alltrue(flatten([for group in ["public", "application", "ipv6-native"] : [
        for cidr in values(output.subnet_ipv6_cidrs[group]) : cidr != null && cidr != ""
      ]])) &&
      length(output.ipv6_native_subnet_ids) == 2 &&
      output.ipv6_route_counts.internet_gateway == 2 &&
      output.ipv6_route_counts.egress_only_igw == 4 &&
      output.ipv6_route_counts.nat64 == 2 &&
      output.nat_gateway_evidence.nat_gateway_count == 1 &&
      output.nat_gateway_evidence.availability_modes == toset(["regional"]) &&
      output.nat_gateway_evidence.managed_eip_count == 0 &&
      output.nat_gateway_evidence.nat_route_count == 2
    )
    error_message = "The dual-stack example must plan one Regional NAT Gateway without module-owned EIPs, dual-stack and IPv6-native subnets, and the documented IPv4, EIGW, and NAT64 routes."
  }
}

run "existing_vpc_example" {
  command = plan

  module {
    source = "./examples/existing_vpc"
  }

  assert {
    condition = (
      toset(keys(output.subnet_ids)) == toset(["application", "public"]) &&
      length(output.nat_gateway_ids) == 2 &&
      output.nat_gateway_evidence.nat_gateway_count == 1 &&
      output.nat_gateway_evidence.availability_modes == toset(["regional"]) &&
      output.nat_gateway_evidence.external_eip_count == 2 &&
      output.nat_gateway_evidence.module_managed_eip_count == 0 &&
      output.nat_gateway_evidence.nat_route_count == 2 &&
      output.module_ownership.vpcs == 0 &&
      output.module_ownership.internet_gateways == 0 &&
      output.module_ownership.elastic_ips == 0 &&
      toset(keys(output.module_ownership.injected_route_tables)) == toset(["external-public"])
    )
    error_message = "The existing-VPC example must inject its VPC, IGW, public route table, and two NAT EIPs while creating subnets, one Regional NAT Gateway, and two NAT routes."
  }
}

run "secure_isolated_example" {
  command = plan

  module {
    source = "./examples/secure_isolated"
  }

  assert {
    condition = (
      toset(keys(output.isolated_subnet_ids)) == toset(["control", "enclave"]) &&
      output.egress_resources.internet_gateway_id == null &&
      length(output.egress_resources.nat_gateway_ids) == 0 &&
      output.egress_resources.egress_only_igw_id == null &&
      output.route_counts.internet == 0 &&
      output.route_counts.nat == 0 &&
      output.route_counts.eigw == 0 &&
      output.default_resource_hardening.security_group_count == 1 &&
      output.default_resource_hardening.network_acl_count == 1 &&
      output.default_resource_hardening.route_table_count == 1 &&
      toset(keys(output.network_acl_controls.ids)) == toset(["control", "enclave"]) &&
      output.network_acl_controls.rule_count == 4 &&
      output.network_acl_controls.association_count == 4
    )
    error_message = "The secure isolated example must harden defaults, manage two explicit stateless NACLs, and retain no egress resources."
  }
}

run "private_nat_example" {
  command = plan

  module {
    source = "./examples/private_nat"
  }

  variables {
    transit_gateway_id = "tgw-0123456789abcdef0"
  }

  assert {
    condition = (
      toset(keys(output.subnet_ids)) == toset(["nat-host", "tgw", "workload"]) &&
      length(output.private_nat_gateway_ids) == 2 &&
      length(output.nat_public_ips) == 0 &&
      output.route_counts.workload_to_nat == 2 &&
      output.route_counts.nat_to_tgw == 4 &&
      output.route_counts.internet == 0
    )
    error_message = "The private-NAT example must plan two private NAT Gateways, workload NAT routes, four translated TGW routes, and no Internet route."
  }
}

run "inspection_egress_example" {
  command = plan

  module {
    source = "./examples/inspection_egress"
  }

  variables {
    transit_gateway_id   = "tgw-0123456789abcdef0"
    spoke_prefix_list_id = "pl-0123456789abcdef0"
  }

  assert {
    condition = (
      toset(keys(output.subnet_ids)) == toset(["firewall", "public", "tgw_attach"]) &&
      length(output.nat_gateway_ids) == 3 &&
      output.network_firewall_inputs.number_azs == 3 &&
      toset(keys(output.network_firewall_inputs.vpc_subnets)) == toset(["us-east-1a", "us-east-1b", "us-east-1c"]) &&
      toset(keys(output.network_firewall_inputs.routing_configuration.centralized_inspection_with_egress.connectivity_subnet_route_tables)) == toset(["us-east-1a", "us-east-1b", "us-east-1c"]) &&
      output.route_evidence.internet_routes == 3 &&
      output.route_evidence.nat_routes == 3 &&
      output.route_evidence.tgw_routes == 3 &&
      alltrue([for destination in values(output.route_evidence.tgw_destinations) :
        destination.cidr_block == null && destination.prefix_list_id == "pl-0123456789abcdef0"
      ])
    )
    error_message = "The inspection-egress example must plan three-AZ NAT egress, appliance-path TGW prefix-list routes, and complete Tier 1 Network Firewall inputs."
  }
}

run "centralized_endpoints_dns_example" {
  command = plan

  module {
    source = "./examples/centralized_endpoints_dns"
  }

  variables {
    resolver_inbound_ips_by_az = {
      us-east-1a = "10.250.16.10"
      us-east-1b = "10.250.16.26"
    }
    resolver_outbound_ips_by_az = {
      us-east-1a = "10.250.16.11"
      us-east-1b = "10.250.16.27"
    }
    ram_principals = ["123456789012"]
  }

  assert {
    condition = (
      toset(keys(output.subnet_ids)) == toset(["endpoints", "resolver", "tgw"]) &&
      alltrue([for group in values(output.subnet_ids) : length(group) == 2]) &&
      length(output.topology_evidence.subnets_by_role.private) == 4 &&
      length(output.topology_evidence.subnets_by_role.transit_gateway) == 2 &&
      toset(keys(output.topology_evidence.hub_attachment)) == toset(["dns-hub"]) &&
      alltrue([for attachments in values(output.topology_evidence.spoke_attachments) : toset(keys(attachments)) == toset(["dns-hub"])]) &&
      output.topology_evidence.tgw_route_table_associations == 3 &&
      output.topology_evidence.tgw_route_table_propagations == 3
    )
    error_message = "The centralized endpoints example must plan the exact two-AZ hub groups, two spokes, and explicit TGW route-table wiring."
  }

  assert {
    condition = (
      alltrue(flatten([for group in ["endpoints", "resolver"] : [
        for connectivity in values(output.connectivity_evidence.by_group_by_az[group]) :
        connectivity.internet == false && connectivity.tgw == true && connectivity.igw == false && connectivity.nat == false && connectivity.eigw == false
      ]])) &&
      output.connectivity_evidence.internet_gateway_id == null &&
      length(output.connectivity_evidence.nat_gateway_ids) == 0 &&
      output.connectivity_evidence.egress_only_igw_id == null &&
      output.connectivity_evidence.transit_route_count == 12 &&
      output.connectivity_evidence.transit_destinations == toset(["10.20.0.0/16", "10.30.0.0/16", "192.0.2.0/24"])
    )
    error_message = "Endpoint and Resolver subnets must have TGW return routes for every consumer and no Internet, NAT, or egress-only gateway path."
  }

  assert {
    condition = (
      toset(keys(output.endpoint_evidence)) == toset(["ec2messages", "logs", "ssm", "ssmmessages", "sts"]) &&
      alltrue([for endpoint in values(output.endpoint_evidence) :
        endpoint.private_dns_enabled == true &&
        length(endpoint.configured_subnet_azs) == 2 &&
        length(endpoint.security_group_ids) == 1 &&
        endpoint.has_policy
      ]) &&
      toset(output.profile_evidence.endpoint_resource_associations) == toset(["ec2messages", "logs", "ssm", "ssmmessages", "sts"]) &&
      toset(output.profile_evidence.vpc_associations) == toset(["application", "hub", "operations"])
    )
    error_message = "Every pedagogical service must use Private DNS, two endpoint AZs, an explicit policy and SG, and Route 53 Profile associations to the hub and spokes."
  }

  assert {
    condition = (
      output.security_evidence.endpoint_https_rule_count == 3 &&
      output.security_evidence.endpoint_https_cidrs == toset(["10.20.0.0/16", "10.30.0.0/16", "192.0.2.0/24"]) &&
      output.security_evidence.wildcard_ipv4_rule_count == 0 &&
      output.dns_attribute_evidence.enable_dns_hostnames == true &&
      output.dns_attribute_evidence.enable_dns_support == true
    )
    error_message = "Endpoint HTTPS authorization must exactly match consumer CIDRs, contain no wildcard source, and preserve both VPC DNS attributes."
  }

  assert {
    condition = (
      toset(keys(output.resolver_evidence.configured_by_az)) == toset(["us-east-1a", "us-east-1b"]) &&
      output.resolver_evidence.configured_by_az["us-east-1a"].inbound_ip == "10.250.16.10" &&
      output.resolver_evidence.configured_by_az["us-east-1b"].inbound_ip == "10.250.16.26" &&
      output.resolver_evidence.configured_by_az["us-east-1a"].outbound_ip == "10.250.16.11" &&
      output.resolver_evidence.configured_by_az["us-east-1b"].outbound_ip == "10.250.16.27" &&
      output.resolver_evidence.inbound.direction == "INBOUND" &&
      output.resolver_evidence.outbound.direction == "OUTBOUND" &&
      length(output.resolver_evidence.inbound.ip_addresses) == 2 &&
      length(output.resolver_evidence.outbound.ip_addresses) == 2 &&
      length(output.resolver_evidence.inbound_security_rules) == 2 &&
      length(output.resolver_evidence.outbound_security_rules) == 4 &&
      alltrue([for rule in values(output.resolver_evidence.inbound_security_rules) : rule.port == 53 && rule.cidr == "192.0.2.0/24"]) &&
      alltrue([for rule in values(output.resolver_evidence.outbound_security_rules) : rule.port == 53 && contains(["192.0.2.53/32", "192.0.2.54/32"], rule.cidr)])
    )
    error_message = "Both Resolver directions must place fixed IPs in two AZs and use only directional TCP/UDP 53 security rules."
  }

  assert {
    condition = (
      toset(keys(output.resolver_rule_evidence.rules)) == toset(["on-premises"]) &&
      output.resolver_rule_evidence.rules["on-premises"].rule_type == "FORWARD" &&
      length(output.resolver_rule_evidence.rules["on-premises"].targets) == 2 &&
      output.resolver_rule_evidence.spoke_association_count == 2 &&
      output.resolver_rule_evidence.ram_resource_count == 1 &&
      output.resolver_rule_evidence.ram_principal_count == 1 &&
      output.resolver_rule_evidence.allow_external == false &&
      output.private_zone_evidence.zones == ["shared"] &&
      output.private_zone_evidence.record_count == 1 &&
      output.private_zone_evidence.initial_vpc_association_count == 1 &&
      output.private_zone_evidence.spoke_association_count == 2
    )
    error_message = "Forwarding rules must be associated separately to both spokes, shared through RAM, and accompanied by direct custom-zone associations."
  }
}

run "centralized_endpoints_dns_rejects_unknown_fixed_ip_az" {
  command = plan

  module {
    source = "./examples/centralized_endpoints_dns"
  }

  variables {
    availability_zones = ["us-east-1a", "us-east-1b"]
    resolver_inbound_ips_by_az = {
      us-east-1a = "10.250.16.10"
      us-east-1b = "10.250.16.26"
      us-east-1c = "10.250.16.42"
    }
    resolver_outbound_ips_by_az = {
      us-east-1a = "10.250.16.11"
      us-east-1b = "10.250.16.27"
    }
  }

  expect_failures = [terraform_data.example_contract]
}

run "centralized_endpoints_dns_rejects_consumer_overlap" {
  command = plan

  module {
    source = "./examples/centralized_endpoints_dns"
  }

  variables {
    availability_zones = ["us-east-1a", "us-east-1b"]
    consumer_cidrs     = ["10.250.1.0/24"]
    resolver_inbound_ips_by_az = {
      us-east-1a = "10.250.16.10"
      us-east-1b = "10.250.16.26"
    }
    resolver_outbound_ips_by_az = {
      us-east-1a = "10.250.16.11"
      us-east-1b = "10.250.16.27"
    }
  }

  expect_failures = [terraform_data.example_contract]
}

run "centralized_endpoints_dns_requires_two_azs" {
  command = plan

  module {
    source = "./examples/centralized_endpoints_dns"
  }

  variables {
    availability_zones = ["us-east-1a"]
  }

  expect_failures = [var.availability_zones]
}
