data "aws_region" "current" {}

locals {
  hub_vpc_cidr = "10.250.0.0/16"

  spokes = {
    application = { cidr = "10.20.0.0/16" }
    operations  = { cidr = "10.30.0.0/16" }
  }

  # One source of truth feeds hub return routes and endpoint authorization.
  consumer_cidrs = distinct(concat(
    [for spoke in values(local.spokes) : spoke.cidr],
    tolist(var.consumer_cidrs),
  ))

  hub_range = {
    start = sum([
      for index, octet in split(".", cidrhost(local.hub_vpc_cidr, 0)) :
      tonumber(octet) * pow(256, 3 - index)
    ])
    end = sum([
      for index, octet in split(".", cidrhost(local.hub_vpc_cidr, 0)) :
      tonumber(octet) * pow(256, 3 - index)
    ]) + pow(2, 32 - tonumber(split("/", local.hub_vpc_cidr)[1])) - 1
  }

  consumer_ranges = {
    for cidr in local.consumer_cidrs : cidr => {
      start = sum([
        for index, octet in split(".", cidrhost(cidr, 0)) :
        tonumber(octet) * pow(256, 3 - index)
      ])
      end = sum([
        for index, octet in split(".", cidrhost(cidr, 0)) :
        tonumber(octet) * pow(256, 3 - index)
      ]) + pow(2, 32 - tonumber(split("/", cidr)[1])) - 1
    }
  }

  endpoint_ingress = {
    for cidr in local.consumer_cidrs : replace(cidr, "/", "-") => cidr
  }

  resolver_inbound_rules = {
    for pair in setproduct(["tcp", "udp"], var.on_prem_dns_cidrs) :
    "${pair[0]}-${replace(pair[1], "/", "-")}" => {
      protocol = pair[0]
      cidr     = pair[1]
    }
  }

  forwarding_targets = merge([
    for rule_key, rule in var.forwarding_rules : {
      for target_key, target in rule.target_ips : "${rule_key}/${target_key}" => merge(target, {
        rule = rule_key
      })
    }
  ]...)

  resolver_outbound_rules = {
    for pair in setproduct(["tcp", "udp"], keys(local.forwarding_targets)) :
    "${pair[0]}-${replace(pair[1], "/", "-")}" => {
      protocol = pair[0]
      ip       = local.forwarding_targets[pair[1]].ip
    }
  }

  profile_vpcs = merge(
    { hub = module.vpc.vpc_id },
    { for key, spoke in module.spokes : key => spoke.vpc_id },
  )

  tgw_attachment_ids = merge(
    { hub = module.vpc.transit_gateway_attachment_ids["dns-hub"] },
    { for key, spoke in module.spokes : key => spoke.transit_gateway_attachment_ids["dns-hub"] },
  )

  resolver_rule_spoke_associations = {
    for pair in setproduct(keys(var.forwarding_rules), keys(local.spokes)) :
    "${pair[0]}/${pair[1]}" => {
      rule  = pair[0]
      spoke = pair[1]
    }
  }

  private_zone_spoke_associations = {
    for pair in setproduct(keys(var.private_zones), keys(local.spokes)) :
    "${pair[0]}/${pair[1]}" => {
      zone  = pair[0]
      spoke = pair[1]
    }
  }

  private_zone_records = merge([
    for zone_key, zone in var.private_zones : {
      for record_key, record in zone.records : "${zone_key}/${record_key}" => merge(record, {
        zone = zone_key
      })
    }
  ]...)
}

resource "terraform_data" "example_contract" {
  input = {
    availability_zones = var.availability_zones
    consumer_cidrs     = local.consumer_cidrs
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for range in values(local.consumer_ranges) :
        range.end < local.hub_range.start || range.start > local.hub_range.end
      ])
      error_message = "consumer_cidrs and generated spoke CIDRs must not overlap the hub VPC CIDR."
    }

    precondition {
      condition = (
        length(setsubtract(toset(keys(var.resolver_inbound_ips_by_az)), toset(var.availability_zones))) == 0 &&
        length(setsubtract(toset(keys(var.resolver_outbound_ips_by_az)), toset(var.availability_zones))) == 0
      )
      error_message = "Resolver fixed-IP map keys must be a subset of availability_zones."
    }
  }
}

resource "aws_ec2_transit_gateway" "shared" {
  description                     = "Centralized endpoint and DNS connectivity"
  dns_support                     = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name    = "centralized-endpoints-dns"
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.shared.id

  tags = {
    Name    = "centralized-endpoints-dns"
    Pattern = "centralized-endpoints-dns"
  }
}

module "vpc" {
  source = "../.."

  vpc = {
    name = "centralized-endpoints-dns"
    dns = {
      enable_hostnames = true
      enable_support   = true
    }
  }

  addressing = {
    primary = { cidr_block = local.hub_vpc_cidr }
  }

  availability_zones = {
    names = var.availability_zones
  }

  subnets = {
    endpoints = {
      role = "private"
      ipv4 = {
        cidrs_by_az = {
          for index, az in var.availability_zones : az => cidrsubnet(local.hub_vpc_cidr, 8, index)
        }
      }
      routing = {
        internet_gateway = false
        transit_gateway_attachments = {
          dns-hub = local.consumer_cidrs
        }
      }
      tags = { Purpose = "centralized-interface-endpoints" }
    }

    resolver = {
      role = "private"
      ipv4 = {
        cidrs_by_az = {
          for index, az in var.availability_zones : az => cidrsubnet(local.hub_vpc_cidr, 12, 256 + index)
        }
      }
      routing = {
        internet_gateway = false
        transit_gateway_attachments = {
          dns-hub = local.consumer_cidrs
        }
      }
      tags = { Purpose = "route53-resolver-inbound-outbound" }
    }

    tgw = {
      role = "transit_gateway"
      ipv4 = {
        cidrs_by_az = {
          for index, az in var.availability_zones : az => cidrsubnet(local.hub_vpc_cidr, 12, 256 + length(var.availability_zones) + index)
        }
      }
      tags = { Purpose = "transit-gateway-attachment" }
    }
  }

  transit_gateway_attachments = {
    dns-hub = {
      subnet_group                    = "tgw"
      id                              = aws_ec2_transit_gateway.shared.id
      default_route_table_association = false
      default_route_table_propagation = false
      dns_support                     = true
      security_group_referencing      = true
    }
  }

  tags = {
    Pattern = "centralized-endpoints-dns"
  }
}

module "spokes" {
  for_each = local.spokes

  source = "../.."

  vpc = {
    name = "centralized-endpoints-dns-${each.key}"
    dns = {
      enable_hostnames = true
      enable_support   = true
    }
  }

  addressing = {
    primary = { cidr_block = each.value.cidr }
  }

  availability_zones = {
    names = var.availability_zones
  }

  subnets = {
    workload = {
      role = "private"
      ipv4 = {
        cidrs_by_az = {
          for index, az in var.availability_zones : az => cidrsubnet(each.value.cidr, 8, index)
        }
      }
      routing = {
        internet_gateway = false
        transit_gateway_attachments = {
          dns-hub = [local.hub_vpc_cidr]
        }
      }
      tags = { Purpose = "private-workloads" }
    }

    tgw = {
      role = "transit_gateway"
      ipv4 = {
        cidrs_by_az = {
          for index, az in var.availability_zones : az => cidrsubnet(each.value.cidr, 12, 256 + index)
        }
      }
      tags = { Purpose = "transit-gateway-attachment" }
    }
  }

  transit_gateway_attachments = {
    dns-hub = {
      subnet_group                    = "tgw"
      id                              = aws_ec2_transit_gateway.shared.id
      default_route_table_association = false
      default_route_table_propagation = false
      dns_support                     = true
      security_group_referencing      = true
    }
  }

  tags = {
    Pattern = "centralized-endpoints-dns"
    Role    = "spoke"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "shared" {
  for_each = local.tgw_attachment_ids

  transit_gateway_attachment_id  = each.value
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "shared" {
  for_each = local.tgw_attachment_ids

  transit_gateway_attachment_id  = each.value
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

resource "aws_security_group" "interface_endpoints" {
  name_prefix = "centralized-interface-endpoints-"
  description = "HTTPS from declared endpoint consumers"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name    = "centralized-interface-endpoints"
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_vpc_security_group_ingress_rule" "interface_endpoints_https" {
  for_each = local.endpoint_ingress

  security_group_id = aws_security_group.interface_endpoints.id
  description       = "HTTPS from ${each.value}"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value.service}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.vpc.subnet_ids_by_group["endpoints"]
  security_group_ids  = [aws_security_group.interface_endpoints.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DeclaredServiceActions"
      Effect    = "Allow"
      Principal = "*"
      Action    = sort(tolist(each.value.actions))
      Resource  = "*"
    }]
  })

  tags = {
    Name    = "centralized-${each.key}"
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_route53profiles_profile" "endpoints" {
  name = "centralized-endpoints-dns"

  tags = {
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_route53profiles_resource_association" "interface_endpoints" {
  for_each = aws_vpc_endpoint.interface

  name         = "centralized-${each.key}"
  profile_id   = aws_route53profiles_profile.endpoints.id
  resource_arn = each.value.arn
}

resource "aws_route53profiles_association" "vpcs" {
  for_each = local.profile_vpcs

  name        = "centralized-${each.key}"
  profile_id  = aws_route53profiles_profile.endpoints.id
  resource_id = each.value

  tags = {
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_route53_zone" "private" {
  for_each = var.private_zones

  name = each.value.name

  vpc {
    vpc_id = module.vpc.vpc_id
  }

  tags = {
    Name    = each.value.name
    Pattern = "centralized-endpoints-dns"
  }

  # Standalone associations own every spoke; the inline block owns only the
  # creation-time hub association and must not absorb refreshed spoke VPCs.
  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_record" "private" {
  for_each = local.private_zone_records

  zone_id = aws_route53_zone.private[each.value.zone].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.values
}

resource "aws_route53_zone_association" "private_spokes" {
  for_each = local.private_zone_spoke_associations

  zone_id    = aws_route53_zone.private[each.value.zone].zone_id
  vpc_id     = module.spokes[each.value.spoke].vpc_id
  vpc_region = data.aws_region.current.region
}

resource "aws_security_group" "resolver_inbound" {
  name_prefix = "centralized-resolver-inbound-"
  description = "Inbound DNS only from declared on-premises resolvers"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name    = "centralized-resolver-inbound"
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_security_group" "resolver_outbound" {
  name_prefix = "centralized-resolver-outbound-"
  description = "Outbound DNS only to declared on-premises resolvers"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name    = "centralized-resolver-outbound"
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_vpc_security_group_ingress_rule" "resolver_inbound_dns" {
  for_each = local.resolver_inbound_rules

  security_group_id = aws_security_group.resolver_inbound.id
  description       = "${upper(each.value.protocol)} DNS from ${each.value.cidr}"
  ip_protocol       = each.value.protocol
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_egress_rule" "resolver_outbound_dns" {
  for_each = local.resolver_outbound_rules

  security_group_id = aws_security_group.resolver_outbound.id
  description       = "${upper(each.value.protocol)} DNS to ${each.value.ip}"
  ip_protocol       = each.value.protocol
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "${each.value.ip}/32"
}

resource "aws_route53_resolver_endpoint" "inbound" {
  count = length(var.availability_zones) >= 2 ? 1 : 0

  name               = "centralized-inbound"
  direction          = "INBOUND"
  protocols          = ["Do53"]
  security_group_ids = [aws_security_group.resolver_inbound.id]

  dynamic "ip_address" {
    for_each = module.vpc.subnet_ids_by_group_by_az["resolver"]

    content {
      subnet_id = ip_address.value
      ip        = lookup(var.resolver_inbound_ips_by_az, ip_address.key, null)
    }
  }

  tags = {
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  count = length(var.availability_zones) >= 2 ? 1 : 0

  name               = "centralized-outbound"
  direction          = "OUTBOUND"
  protocols          = ["Do53"]
  security_group_ids = [aws_security_group.resolver_outbound.id]

  dynamic "ip_address" {
    for_each = module.vpc.subnet_ids_by_group_by_az["resolver"]

    content {
      subnet_id = ip_address.value
      ip        = lookup(var.resolver_outbound_ips_by_az, ip_address.key, null)
    }
  }

  tags = {
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_route53_resolver_rule" "forward" {
  for_each = length(var.availability_zones) >= 2 ? var.forwarding_rules : {}

  name                 = each.key
  domain_name          = each.value.domain_name
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound[0].id

  dynamic "target_ip" {
    for_each = each.value.target_ips

    content {
      ip       = target_ip.value.ip
      port     = target_ip.value.port
      protocol = "Do53"
    }
  }

  tags = {
    Name    = each.key
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_route53_resolver_rule_association" "spokes" {
  for_each = length(var.availability_zones) >= 2 ? local.resolver_rule_spoke_associations : {}

  name             = "${each.value.rule}-${each.value.spoke}"
  resolver_rule_id = aws_route53_resolver_rule.forward[each.value.rule].id
  vpc_id           = module.spokes[each.value.spoke].vpc_id
}

resource "aws_ram_resource_share" "resolver_rules" {
  name                      = "centralized-dns-forwarding-rules"
  allow_external_principals = var.allow_external_principals

  tags = {
    Pattern = "centralized-endpoints-dns"
  }
}

resource "aws_ram_resource_association" "resolver_rules" {
  for_each = aws_route53_resolver_rule.forward

  resource_arn       = each.value.arn
  resource_share_arn = aws_ram_resource_share.resolver_rules.arn
}

resource "aws_ram_principal_association" "resolver_rules" {
  for_each = var.ram_principals

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.resolver_rules.arn
}
