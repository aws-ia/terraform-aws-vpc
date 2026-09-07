# ─────────────────────────────────────────────────────────────────────────────
# terraform-aws-vpc v5 — VPC Lattice Service Network association (Phase 3)
# ─────────────────────────────────────────────────────────────────────────────

locals {
  vpc_lattice_association_id = !var.vpc_lattice.enabled ? null : (
    var.vpc_lattice.create
    ? try(aws_vpclattice_service_network_vpc_association.this["vpc"].id, null)
    : var.vpc_lattice.id
  )
}

resource "aws_vpclattice_service_network_vpc_association" "this" {
  for_each = var.vpc_lattice.enabled && var.vpc_lattice.create ? { vpc = var.vpc_lattice } : {}

  vpc_identifier             = local.vpc_id
  service_network_identifier = each.value.service_network_identifier
  security_group_ids         = each.value.security_group_ids
  private_dns_enabled        = each.value.private_dns_enabled

  # AWS materializes dns_options even when the create request omits it. Provider
  # 6.59 then flattens VERIFIED_DOMAINS_ONLY plus its computed ["*"] sentinel,
  # and removing that ForceNew block would replace the association on every plan.
  # Pin the preference; leave specified domains null unless the selected mode uses
  # them so the provider can absorb AWS's computed sentinel without configuration
  # drift.
  dynamic "dns_options" {
    for_each = each.value.private_dns_enabled ? [each.value.dns_options] : []

    content {
      private_dns_preference        = dns_options.value.private_dns_preference
      private_dns_specified_domains = dns_options.value.private_dns_specified_domains
    }
  }

  tags = merge(var.tags, each.value.tags, {
    Name = "${var.vpc.name}-service-network-association"
  })

  lifecycle {
    precondition {
      condition     = length(trimspace(each.value.service_network_identifier)) > 0
      error_message = "vpc_lattice.service_network_identifier must not be empty."
    }
  }
}
