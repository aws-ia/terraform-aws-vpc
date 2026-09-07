output "vpc_id" {
  description = "ID of the centralized endpoints and DNS hub VPC."
  value       = module.vpc.vpc_id
}

output "spoke_vpc_ids" {
  description = "Spoke VPC IDs by stable caller key."
  value       = { for key, spoke in module.spokes : key => spoke.vpc_id }
}

output "subnet_ids" {
  description = "Hub subnet IDs by group and Availability Zone."
  value       = module.vpc.subnet_ids_by_group_by_az
}

output "topology_evidence" {
  description = "Subnet-role and TGW attachment evidence for the hub-and-spoke topology."
  value = {
    subnets_by_role = module.vpc.subnet_ids_by_semantic_role
    hub_attachment  = module.vpc.transit_gateway_attachment_ids
    spoke_attachments = {
      for key, spoke in module.spokes : key => spoke.transit_gateway_attachment_ids
    }
    tgw_route_table_associations = length(aws_ec2_transit_gateway_route_table_association.shared)
    tgw_route_table_propagations = length(aws_ec2_transit_gateway_route_table_propagation.shared)
  }
}

output "connectivity_evidence" {
  description = "Effective hub connectivity and Internet-resource evidence by subnet group and AZ."
  value = {
    by_group_by_az       = module.vpc.subnet_connectivity_by_group_by_az
    internet_gateway_id  = module.vpc.internet_gateway_id
    nat_gateway_ids      = module.vpc.nat_gateway_ids
    egress_only_igw_id   = module.vpc.egress_only_igw_id
    transit_route_count  = length(module.vpc.resources.routes.tgw_attachment)
    transit_destinations = toset([for route in values(module.vpc.resources.routes.tgw_attachment) : route.destination_cidr_block])
  }
}

output "endpoint_evidence" {
  description = "Interface endpoint DNS, subnet, security-group, policy, and service evidence by key."
  value = {
    for key, endpoint in aws_vpc_endpoint.interface : key => {
      private_dns_enabled   = endpoint.private_dns_enabled
      service_name          = endpoint.service_name
      configured_subnet_azs = keys(module.vpc.subnet_ids_by_group_by_az["endpoints"])
      subnet_ids            = endpoint.subnet_ids
      security_group_ids    = endpoint.security_group_ids
      has_policy            = endpoint.policy != null
    }
  }
}

output "profile_evidence" {
  description = "Route 53 Profile resource and VPC association identities."
  value = {
    profile_id                     = aws_route53profiles_profile.endpoints.id
    endpoint_resource_associations = keys(aws_route53profiles_resource_association.interface_endpoints)
    vpc_associations               = keys(aws_route53profiles_association.vpcs)
  }
}

output "resolver_evidence" {
  description = "Resolver endpoint placement, directions, and directional security-group rule evidence."
  value = {
    configured_by_az = {
      for az, subnet_id in module.vpc.subnet_ids_by_group_by_az["resolver"] : az => {
        subnet_id   = subnet_id
        inbound_ip  = lookup(var.resolver_inbound_ips_by_az, az, null)
        outbound_ip = lookup(var.resolver_outbound_ips_by_az, az, null)
      }
    }
    inbound = length(aws_route53_resolver_endpoint.inbound) > 0 ? {
      direction    = aws_route53_resolver_endpoint.inbound[0].direction
      ip_addresses = aws_route53_resolver_endpoint.inbound[0].ip_address
    } : null
    outbound = length(aws_route53_resolver_endpoint.outbound) > 0 ? {
      direction    = aws_route53_resolver_endpoint.outbound[0].direction
      ip_addresses = aws_route53_resolver_endpoint.outbound[0].ip_address
    } : null
    inbound_security_rules = {
      for key, rule in aws_vpc_security_group_ingress_rule.resolver_inbound_dns : key => {
        protocol = rule.ip_protocol
        cidr     = rule.cidr_ipv4
        port     = rule.from_port
      }
    }
    outbound_security_rules = {
      for key, rule in aws_vpc_security_group_egress_rule.resolver_outbound_dns : key => {
        protocol = rule.ip_protocol
        cidr     = rule.cidr_ipv4
        port     = rule.from_port
      }
    }
  }
}

output "resolver_rule_evidence" {
  description = "Forwarding, spoke association, and RAM sharing evidence."
  value = {
    rules = {
      for key, rule in aws_route53_resolver_rule.forward : key => {
        domain_name = rule.domain_name
        rule_type   = rule.rule_type
        targets     = rule.target_ip
      }
    }
    spoke_association_count = length(aws_route53_resolver_rule_association.spokes)
    ram_resource_count      = length(aws_ram_resource_association.resolver_rules)
    ram_principal_count     = length(aws_ram_principal_association.resolver_rules)
    allow_external          = aws_ram_resource_share.resolver_rules.allow_external_principals
  }
}

output "private_zone_evidence" {
  description = "Private hosted zone, record, and direct spoke association evidence."
  value = {
    zones                         = keys(aws_route53_zone.private)
    record_count                  = length(aws_route53_record.private)
    initial_vpc_association_count = length(aws_route53_zone.private)
    spoke_association_count       = length(aws_route53_zone_association.private_spokes)
  }
}

output "security_evidence" {
  description = "HTTPS endpoint authorization and absence of wildcard IPv4 sources."
  value = {
    endpoint_https_cidrs = toset([
      for rule in values(aws_vpc_security_group_ingress_rule.interface_endpoints_https) : rule.cidr_ipv4
    ])
    endpoint_https_rule_count = length(aws_vpc_security_group_ingress_rule.interface_endpoints_https)
    wildcard_ipv4_rule_count = length([
      for cidr in concat(
        [for rule in values(aws_vpc_security_group_ingress_rule.interface_endpoints_https) : rule.cidr_ipv4],
        [for rule in values(aws_vpc_security_group_ingress_rule.resolver_inbound_dns) : rule.cidr_ipv4],
        [for rule in values(aws_vpc_security_group_egress_rule.resolver_outbound_dns) : rule.cidr_ipv4],
      ) : cidr if cidr == "0.0.0.0/0"
    ])
  }
}

output "dns_attribute_evidence" {
  description = "Hub VPC DNS attributes required by Profiles, hosted zones, and Resolver."
  value = {
    enable_dns_hostnames = module.vpc.resources.vpc.created[0].enable_dns_hostnames
    enable_dns_support   = module.vpc.resources.vpc.created[0].enable_dns_support
  }
}
