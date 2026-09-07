# Attachments

Attachment contracts separate caller-owned identity from external network IDs. Routes select attachment keys, so changing an external gateway can preserve Terraform addresses when the caller key remains stable.

## Transit Gateway attachment model

Use the top-level plural map for all new configurations:

```hcl
transit_gateway_attachments = {
  east = {
    subnet_group                    = "tgw"
    id                              = var.transit_gateway_ids["east"]
    default_route_table_association = false
    default_route_table_propagation = false
    appliance_mode_support          = true
    dns_support                     = true
    security_group_referencing      = true
  }
  west = {
    subnet_group = "tgw"
    id           = var.transit_gateway_ids["west"]
  }
}
```

The `east` and `west` keys are state identity. Each attachment selects a subnet group whose role is `transit_gateway`; several attachments may intentionally reuse the same attachment subnets. A VPC may configure up to five entries, and each entry must select a distinct Transit Gateway because AWS allows only one attachment between a VPC and a given TGW.

Each attachment independently supports create or inject ownership. Create mode owns the VPC attachment. Inject mode uses `create = false` plus `attachment_id`, while routes may still target that effective attachment.

The singular `subnets[*].transit_gateway_options` and singular TGW route fields are deprecated compatibility adapters. Do not combine them with the top-level plural map; new configurations should use keyed attachments and keyed route maps.

## Transit Gateway routes

Workload groups select attachment keys and destination lists:

```hcl
routing = {
  transit_gateway_attachments = {
    east = ["10.0.0.0/8", "172.16.0.0/12"]
    west = ["pl-0123456789abcdef0"]
  }
  transit_gateway_attachments_ipv6 = {
    east = ["2001:db8:100::/48"]
  }
}
```

IPv4 and IPv6 lists accept CIDRs and customer-managed prefix-list IDs. Every selected key must exist in `transit_gateway_attachments`. Preserve the key when changing only the TGW ID, attachment options, tags, or destination values.

Enable appliance mode for stateful inspection paths that require forward and return traffic to remain in the same AZ. Default TGW route-table association and propagation are separate controls; disabling both leaves routing policy with the TGW owner.

## Cloud WAN attachment

Cloud WAN uses one subnet group with role `core_network` and one VPC attachment:

```hcl
subnets = {
  cwan = {
    role = "core_network"
    ipv4 = { netmask = 28 }
    core_network_options = {
      id                 = var.core_network_id
      arn                = var.core_network_arn
      require_acceptance = true
      accept_attachment  = true
    }
  }
}
```

Create mode owns the Network Manager VPC attachment; inject mode uses `create = false` plus `attachment_id`. `core_network` and `core_network_ipv6` route lists on other subnet groups target the effective attachment.

Optional attachment arguments: `routing_policy_label` applies a routing policy label for traffic routing decisions, and `dns_support` / `security_group_referencing` map to the attachment options block. All three default to `null`, deferring to the AWS service defaults so existing attachments see no diff.

## Cloud WAN acceptance ownership

Acceptance is an explicit lifecycle boundary:

- `require_acceptance = false` means no acceptance step blocks route creation.
- `require_acceptance = true` and `accept_attachment = true` lets this module own same-account acceptance.
- `create_accepter = true` creates the accepter; `create_accepter = false` injects an existing `accepter_id`.
- Cross-account acceptance remains with the Core Network owner. Set `accept_attachment = false`, apply without Cloud WAN routes, accept through an owner-account provider or workflow, then set `require_acceptance = false` and add routes.

The module rejects Cloud WAN routes while required acceptance is external. This prevents route creation from racing an attachment that is not yet usable. It also rejects module-managed acceptance when the supplied Core Network ARN identifies another account.

## VPC Lattice service-network association

`vpc_lattice.enabled` is the plan-known selector. Create mode requires a service-network identifier and owns the VPC association; inject mode uses `create = false` plus the association `id` and omits service-network and security-group fields.

```hcl
vpc_lattice = {
  enabled                    = true
  service_network_identifier = aws_vpclattice_service_network.shared.id
  security_group_ids         = [aws_security_group.lattice.id]
  private_dns_enabled        = true
}
```

Up to five security groups may be supplied in create mode. Private DNS defaults to `VERIFIED_DOMAINS_ONLY`. Specified domains are valid only with `VERIFIED_DOMAINS_AND_SPECIFIED_DOMAINS` or `SPECIFIED_DOMAINS_ONLY`, with 1–10 domain names.

DNS option changes replace the VPC Lattice association under provider semantics. Review private DNS changes as attachment cutovers and preserve the association key `vpc` during migrations.

During VPC Lattice association destroy, the provider can report `Plugin did not respond` while AWS continues deleting asynchronously; retrying the destroy converges.

## Composition outputs

Prefer these Tier 1 handles:

- `transit_gateway_attachment_ids`: map keyed by caller attachment identity;
- `core_network_attachment_id`: effective Cloud WAN attachment ID;
- `core_network_attachment_accepter_id`: managed or injected accepter ID when selected;
- `vpc_lattice_service_network_association_id`: effective Lattice association ID;
- `subnet_ids_by_group_by_az` and `route_table_ids_by_group_by_az`: attachment and connectivity subnet composition.

The deprecated scalar TGW output represents only the compatibility adapter and is not the contract for plural attachments.

## Attachment checklist

- Use stable top-level keys for every TGW attachment.
- Keep attachment subnet roles and AZ sets consistent with the VPC topology.
- Decide TGW association, propagation, appliance mode, DNS, and security-group referencing explicitly.
- Assign Cloud WAN acceptance to exactly one account and state owner.
- Add Cloud WAN routes only after the attachment no longer requires external acceptance.
- Treat VPC Lattice DNS changes as replacement-sensitive.
