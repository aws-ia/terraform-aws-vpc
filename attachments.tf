# ─────────────────────────────────────────────────────────────────────────────
# terraform-aws-vpc v5 — Transit Gateway and Cloud WAN attachments (Phase 3)
#
# Attachments use caller-owned keys; legacy adapters retain the key "vpc".
# Inputs reference only scalar IDs/ARNs and child resource attributes;
# no complete data-source object can become unknown and force replacement.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # A subnet group may be reused by several distinct TGW attachments. The
  # legacy embedded options produce the historical singleton key "vpc".
  transit_gateway_group = try([
    for name, cfg in var.subnets : name
    if cfg.role == "transit_gateway" && cfg.transit_gateway_options != null
  ][0], null)

  legacy_core_network_group = try([
    for name, cfg in var.subnets : name
    if cfg.role == "core_network" && cfg.core_network_options != null
  ][0], null)

  plural_transit_gateway_attachments = {
    for key, cfg in var.transit_gateway_attachments : key => {
      group   = cfg.subnet_group
      options = cfg
      tags    = merge(try(var.subnets[cfg.subnet_group].tags, {}), cfg.tags)
      ipv6    = try(var.subnets[cfg.subnet_group].ipv6 != null, false)
    }
  }
  legacy_transit_gateway_attachments = local.transit_gateway_group == null ? {} : {
    vpc = {
      group   = local.transit_gateway_group
      options = var.subnets[local.transit_gateway_group].transit_gateway_options
      tags    = var.subnets[local.transit_gateway_group].tags
      ipv6    = try(var.subnets[local.transit_gateway_group].ipv6 != null, false)
    }
  }
  effective_transit_gateway_attachments = length(var.transit_gateway_attachments) > 0 ? local.plural_transit_gateway_attachments : local.legacy_transit_gateway_attachments
  transit_gateway_attachments_to_create = {
    for key, attachment in local.effective_transit_gateway_attachments : key => attachment
    if attachment.options.create
  }
  transit_gateway_attachment_ids = {
    for key, attachment in local.effective_transit_gateway_attachments : key => (
      attachment.options.create
      ? try(aws_ec2_transit_gateway_vpc_attachment.this[key].id, null)
      : attachment.options.attachment_id
    )
  }
  transit_gateway_ids_by_attachment = {
    for key, attachment in local.effective_transit_gateway_attachments : key => attachment.options.id
  }
  singular_tgw_route_key = length(local.effective_transit_gateway_attachments) == 1 ? one(keys(local.effective_transit_gateway_attachments)) : null
  transit_gateway_attachment_id = local.transit_gateway_group != null ? try(local.transit_gateway_attachment_ids.vpc, null) : (
    length(local.transit_gateway_attachment_ids) == 1 ? one(values(local.transit_gateway_attachment_ids)) : null
  )

  referenced_tgw_attachment_keys = distinct(flatten([
    for name, cfg in var.subnets : concat(
      keys(try(cfg.routing.transit_gateway_attachments, {})),
      keys(try(cfg.routing.transit_gateway_attachments_ipv6, {})),
    )
  ]))
  any_singular_transit_gateway_routes = anytrue([
    for name, cfg in var.subnets :
    length(coalesce(try(cfg.routing.transit_gateway, null), [])) > 0 ||
    length(coalesce(try(cfg.routing.transit_gateway_ipv6, null), [])) > 0
  ])
  any_transit_gateway_routes = local.any_singular_transit_gateway_routes || length(local.referenced_tgw_attachment_keys) > 0

  plural_core_network_attachments = {
    for key, cfg in var.core_network_attachments : key => {
      group   = cfg.subnet_group
      options = cfg
      tags    = merge(try(var.subnets[cfg.subnet_group].tags, {}), cfg.tags)
      ipv6    = try(var.subnets[cfg.subnet_group].ipv6 != null, false)
    }
  }
  legacy_core_network_attachments = local.legacy_core_network_group == null ? {} : {
    vpc = {
      group   = local.legacy_core_network_group
      options = var.subnets[local.legacy_core_network_group].core_network_options
      tags    = var.subnets[local.legacy_core_network_group].tags
      ipv6    = try(var.subnets[local.legacy_core_network_group].ipv6 != null, false)
    }
  }
  effective_core_network_attachments = length(var.core_network_attachments) > 0 ? local.plural_core_network_attachments : local.legacy_core_network_attachments
  core_network_attachments_to_create = {
    for key, attachment in local.effective_core_network_attachments : key => attachment
    if attachment.options.create
  }

  # Construct the immutable VPC ARN from scalar identity components. In inject
  # mode this avoids data.aws_vpc.existing[0].arn and its whole-object unknowns.
  constructed_vpc_arn = length(local.effective_core_network_attachments) == 0 ? null : format(
    "arn:%s:ec2:%s:%s:vpc/%s",
    data.aws_partition.current[0].partition,
    data.aws_region.current[0].region,
    data.aws_caller_identity.current[0].account_id,
    local.vpc_id
  )

  core_network_attachment_ids = {
    for key, attachment in local.effective_core_network_attachments : key => (
      attachment.options.create
      ? try(aws_networkmanager_vpc_attachment.this[key].id, null)
      : attachment.options.attachment_id
    )
  }
  core_network_accepters_to_create = {
    for key, attachment in local.effective_core_network_attachments : key => {
      attachment_id = local.core_network_attachment_ids[key]
    }
    if attachment.options.require_acceptance && attachment.options.accept_attachment && attachment.options.create_accepter
  }
  core_network_accepter_ids = {
    for key, attachment in local.effective_core_network_attachments : key => (
      attachment.options.create_accepter
      ? try(aws_networkmanager_attachment_accepter.this[key].id, null)
      : attachment.options.accepter_id
    ) if attachment.options.accept_attachment
  }
  singular_cwan_route_key    = length(local.effective_core_network_attachments) == 1 ? one(keys(local.effective_core_network_attachments)) : null
  core_network_attachment_id = try(local.core_network_attachment_ids[local.singular_cwan_route_key], null)
  core_network_accepter_id   = try(local.core_network_accepter_ids[local.singular_cwan_route_key], null)

  referenced_cwan_attachment_keys = distinct(flatten([
    for name, cfg in var.subnets : concat(
      keys(cfg.routing.core_network_attachments),
      keys(cfg.routing.core_network_attachments_ipv6),
    )
  ]))
  any_singular_core_network_routes = anytrue([
    for name, cfg in var.subnets :
    length(coalesce(try(cfg.routing.core_network, null), [])) > 0 ||
    length(coalesce(try(cfg.routing.core_network_ipv6, null), [])) > 0
  ])
  any_core_network_routes = local.any_singular_core_network_routes || length(local.referenced_cwan_attachment_keys) > 0
  # Only non-empty route lists require the target to be accepted. An unrelated
  # pending attachment must not block routes to an already usable attachment.
  routed_cwan_attachment_keys = toset(concat(
    local.any_singular_core_network_routes && local.singular_cwan_route_key != null ? [local.singular_cwan_route_key] : [],
    flatten([
      for cfg in values(var.subnets) : concat(
        [for key, destinations in cfg.routing.core_network_attachments : key if length(destinations) > 0],
        [for key, destinations in cfg.routing.core_network_attachments_ipv6 : key if length(destinations) > 0],
      )
    ]),
  ))
}

data "aws_partition" "current" {
  count = length(local.effective_core_network_attachments) > 0 || length(local.cloudwatch_roles_to_create) > 0 ? 1 : 0
}

data "aws_region" "current" {
  count = length(local.effective_core_network_attachments) > 0 || length(local.cloudwatch_roles_to_create) > 0 || length(local.gateway_endpoints_to_create) > 0 ? 1 : 0
}

resource "terraform_data" "attachment_contract_validation" {
  input = {
    transit_gateway_attachments = keys(local.effective_transit_gateway_attachments)
    core_network_attachments    = keys(local.effective_core_network_attachments)
  }

  lifecycle {
    precondition {
      condition     = !(length(var.transit_gateway_attachments) > 0 && local.transit_gateway_group != null)
      error_message = "Do not combine top-level transit_gateway_attachments with the deprecated singular subnets[*].transit_gateway_options adapter."
    }

    precondition {
      condition = alltrue([
        for key, attachment in var.transit_gateway_attachments :
        contains(keys(var.subnets), attachment.subnet_group) && try(var.subnets[attachment.subnet_group].role, null) == "transit_gateway"
      ])
      error_message = "Every transit_gateway_attachments[*].subnet_group must reference an existing subnet group with role='transit_gateway'."
    }

    precondition {
      condition     = !local.any_transit_gateway_routes || length(local.effective_transit_gateway_attachments) > 0
      error_message = "A subnet group declares Transit Gateway routes, but no effective TGW attachment is configured."
    }

    precondition {
      condition     = !local.any_singular_transit_gateway_routes || local.singular_tgw_route_key != null
      error_message = "Deprecated singular TGW route lists require exactly one effective attachment; use routing.transit_gateway_attachments keyed by attachment when more than one exists."
    }

    precondition {
      condition     = length(setsubtract(toset(local.referenced_tgw_attachment_keys), toset(keys(local.effective_transit_gateway_attachments)))) == 0
      error_message = "TGW routes reference unknown attachment keys: ${join(", ", sort(tolist(setsubtract(toset(local.referenced_tgw_attachment_keys), toset(keys(local.effective_transit_gateway_attachments))))))}."
    }

    precondition {
      condition     = !(length(var.core_network_attachments) > 0 && local.legacy_core_network_group != null)
      error_message = "Do not combine top-level core_network_attachments with the deprecated subnets[*].core_network_options adapter."
    }

    precondition {
      condition = alltrue([
        for attachment in values(var.core_network_attachments) :
        try(var.subnets[attachment.subnet_group].role, null) == "core_network"
      ])
      error_message = "Every core_network_attachments[*].subnet_group must reference an existing subnet group with role='core_network'."
    }

    precondition {
      condition     = !local.any_core_network_routes || length(local.effective_core_network_attachments) > 0
      error_message = "A subnet group declares Cloud WAN routes, but no effective Core Network attachment is configured."
    }

    precondition {
      condition     = !local.any_singular_core_network_routes || local.singular_cwan_route_key != null
      error_message = "Singular Cloud WAN route lists require exactly one effective attachment; use routing.core_network_attachments keyed by attachment when more than one exists."
    }

    precondition {
      condition     = length(setsubtract(toset(local.referenced_cwan_attachment_keys), toset(keys(local.effective_core_network_attachments)))) == 0
      error_message = "Cloud WAN routes reference unknown attachment keys: ${join(", ", sort(tolist(setsubtract(toset(local.referenced_cwan_attachment_keys), toset(keys(local.effective_core_network_attachments))))))}."
    }

    precondition {
      condition = alltrue([
        for attachment in values(local.effective_core_network_attachments) :
        attachment.options.arn == null ||
        can(regex(
          "^arn:${data.aws_partition.current[0].partition}:networkmanager::[0-9]{12}:core-network/${attachment.options.id}$",
          attachment.options.arn
        ))
      ])
      error_message = "Cloud WAN arn must be a complete Network Manager Core Network ARN matching the attachment's Core Network id."
    }

    precondition {
      condition = alltrue([
        for attachment in values(local.effective_core_network_attachments) :
        !attachment.options.require_acceptance || !attachment.options.accept_attachment ||
        try(split(":", attachment.options.arn)[4], data.aws_caller_identity.current[0].account_id) == data.aws_caller_identity.current[0].account_id
      ])
      error_message = "accept_attachment = true supports same-account Core Networks only. For a shared cross-account Core Network, set accept_attachment = false and accept it with the owner-account provider."
    }

    precondition {
      condition = alltrue([
        for key, attachment in local.effective_core_network_attachments :
        !contains(local.routed_cwan_attachment_keys, key) ||
        !attachment.options.require_acceptance || attachment.options.accept_attachment
      ])
      error_message = "Cloud WAN routes cannot be created while the attachment requires external acceptance. First apply without Core Network routes, accept the attachment externally, then set require_acceptance = false and add the routes."
    }
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = local.transit_gateway_attachments_to_create

  transit_gateway_id = each.value.options.id
  vpc_id             = local.vpc_id
  subnet_ids = [
    for az in local.azs : local.subnet_ids["${each.value.group}/${az}"]
  ]

  transit_gateway_default_route_table_association = each.value.options.default_route_table_association
  transit_gateway_default_route_table_propagation = each.value.options.default_route_table_propagation
  appliance_mode_support                          = each.value.options.appliance_mode_support ? "enable" : "disable"
  dns_support                                     = each.value.options.dns_support ? "enable" : "disable"
  ipv6_support                                    = each.value.ipv6 ? "enable" : "disable"
  security_group_referencing_support              = each.value.options.security_group_referencing ? "enable" : "disable"

  tags = merge(var.tags, each.value.tags, {
    Name = each.key == "vpc" ? "${var.vpc.name}-tgw-attachment" : "${var.vpc.name}-tgw-attachment-${each.key}"
  })

  depends_on = [terraform_data.attachment_contract_validation]

  lifecycle {
    precondition {
      condition     = length(trimspace(each.value.options.id)) > 0
      error_message = "Transit Gateway id must not be empty."
    }
  }
}

resource "aws_networkmanager_vpc_attachment" "this" {
  for_each = local.core_network_attachments_to_create

  core_network_id = each.value.options.id
  vpc_arn         = local.constructed_vpc_arn
  subnet_arns = [
    for az in local.azs : local.subnet_arns["${each.value.group}/${az}"]
  ]

  routing_policy_label = each.value.options.routing_policy_label

  options {
    appliance_mode_support = each.value.options.appliance_mode
    ipv6_support           = each.value.ipv6
    # null defers to the AWS service defaults so existing attachments see no diff
    dns_support                        = each.value.options.dns_support
    security_group_referencing_support = each.value.options.security_group_referencing
  }

  tags = merge(var.tags, each.value.tags, {
    Name = each.key == "vpc" ? "${var.vpc.name}-core-network-attachment" : "${var.vpc.name}-core-network-attachment-${each.key}"
  })

  depends_on = [terraform_data.attachment_contract_validation]

  lifecycle {
    precondition {
      condition     = length(trimspace(each.value.options.id)) > 0
      error_message = "core_network_options.id must not be empty."
    }
  }
}

resource "aws_networkmanager_attachment_accepter" "this" {
  for_each = local.core_network_accepters_to_create

  attachment_id   = each.value.attachment_id
  attachment_type = "VPC"

  depends_on = [terraform_data.attachment_contract_validation]
}

# Routes must wait for the effective attachment and, when managed, its accepter.
# Consuming injected IDs here preserves dependency edges from upstream modules
# even though aws_route only receives the Core Network ARN.
resource "terraform_data" "core_network_readiness" {
  for_each = {
    for key, attachment in local.effective_core_network_attachments : key => attachment
    if contains(local.routed_cwan_attachment_keys, key)
  }

  input = {
    attachment_id = local.core_network_attachment_ids[each.key]
    accepter_id   = try(local.core_network_accepter_ids[each.key], null)
  }

  depends_on = [
    terraform_data.attachment_contract_validation,
    aws_networkmanager_vpc_attachment.this,
    aws_networkmanager_attachment_accepter.this,
  ]
}
