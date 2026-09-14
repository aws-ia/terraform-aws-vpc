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

## Cloud WAN attachments

Use `core_network_attachments` for new configurations. Each stable key selects a
subnet group with role `core_network` and owns an independent VPC attachment:

```hcl
subnets = {
  cwan_blue = {
    role = "core_network"
    ipv4 = { netmask = 28 }
  }
  cwan_green = {
    role = "core_network"
    ipv4 = { netmask = 28 }
  }
}

core_network_attachments = {
  blue = {
    subnet_group = "cwan_blue"
    id           = var.blue_core_network_id
    arn          = var.blue_core_network_arn
    tags         = { environment = "blue" }
  }
  green = {
    subnet_group       = "cwan_green"
    id                 = var.green_core_network_id
    arn                = var.green_core_network_arn
    appliance_mode     = true
    require_acceptance = true
    accept_attachment  = true
    tags               = { environment = "green" }
  }
}
```

AWS permits [up to five core network attachments per VPC](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html).
The module supports multiple `core_network` subnet groups and permits attachments
to reuse a group. Each attachment selects one subnet per configured AZ. Create
mode owns the Network Manager VPC attachment; inject mode uses `create = false`
plus `attachment_id`. Attachment tags override group tags and global tags; the
module supplies the Name tag. For a shared Core Network, supply its owner ARN;
otherwise the ARN is derived from `id`, the current account and partition.

Workload groups select attachment keys and IPv4/IPv6 destination lists:

```hcl
routing = {
  core_network_attachments = {
    blue  = ["10.0.0.0/8", "pl-0123456789abcdef0"]
    green = ["172.16.0.0/12"]
  }
  core_network_attachments_ipv6 = {
    green = ["2001:db8:100::/48"]
  }
}
```

Both families accept CIDRs or managed prefix-list IDs. Route keys include the
attachment key; unknown keys and conflicting destinations on the same physical
route table are rejected. Matching declarations from groups sharing an injected
table are merged into one route. CIDRs in keyed maps are canonicalized before
aggregation and state-key construction, so equivalent IPv6 spellings identify the
same physical destination. The legacy adapter retains its original route keys.
AWS VPC routes target the selected **Core Network
ARN**, not an attachment ID or a segment name: segment association and reachability
remain governed by Cloud WAN policy. The attachment map does not bypass those
service-level rules.

Optional attachment arguments: `routing_policy_label` applies a routing policy label for traffic routing decisions, and `dns_support` / `security_group_referencing` map to the attachment options block. All three default to `null`, deferring to the AWS service defaults so existing attachments see no diff.

## Cloud WAN acceptance ownership

Acceptance is an explicit lifecycle boundary:

- `require_acceptance = false` means no acceptance step blocks route creation.
- `require_acceptance = true` and `accept_attachment = true` lets this module own same-account acceptance.
- `create_accepter = true` creates the accepter; `create_accepter = false` injects an existing `accepter_id`.
- Cross-account acceptance remains with the Core Network owner. Set `accept_attachment = false`, apply without Cloud WAN routes, accept through an owner-account provider or workflow, then set `require_acceptance = false` and add routes.

These settings apply independently to each attachment. The module rejects routes
to an attachment while its required acceptance is external; an unrouted pending
attachment does not block routes to other attachments. Routes depend on effective
attachment/accepter IDs, including injected IDs computed by upstream modules. The
module also rejects managed acceptance when the supplied Core Network ARN
identifies another account.

## Migrating the Cloud WAN singleton adapter

`subnets[*].core_network_options` is deprecated and scheduled for removal in v6.
It may appear on at most one group and cannot be combined with the top-level map.
During v5 it preserves attachment, accepter and readiness addresses keyed by
`"vpc"`, Name tags, and the existing `aws_route.cwan` / `aws_route.cwan_ipv6`
addresses. Keeping the adapter requires no state moves.

To adopt the map incrementally, move the options to
`core_network_attachments.vpc`, add `subnet_group`, and remove the embedded options.
This retains the attachment/accepter addresses and Name tags. Singular
`routing.core_network` / `routing.core_network_ipv6` lists still work while exactly
one attachment exists. Update full-object consumers to the plural ID outputs.

Before adding a second attachment, replace singular routes with keyed maps and
move each route address in the caller root module, for example:

```hcl
moved {
  from = module.vpc.aws_route.cwan["application/us-east-1a/cwan/10.0.0.0-8"]
  to   = module.vpc.aws_route.cwan_attachment["application/us-east-1a/cwan/vpc/10.0.0.0-8"]
}
moved {
  from = module.vpc.aws_route.cwan_ipv6["application/us-east-1a/cwan6/2001:db8:100::-48"]
  to   = module.vpc.aws_route.cwan_attachment_ipv6["application/us-east-1a/cwan6/vpc/2001:db8:100::-48"]
}
```

Repeat for every managed route, using `injected/<route_table_key>` in place of
`<group>/<az>` for injected tables. Use a full plan to verify there is no unintended
replacement. Renaming attachment keys also requires caller-owned state moves;
retaining `vpc` is the simplest migration path.

## Shifting routes between existing attachments

Attachment keys are also part of route state identity, matching the TGW contract.
Moving a destination from `blue` to `green` changes the Terraform route address.
For a make-before-break cutover, **include a caller-owned `moved` block for each
route being shifted**. Moving only the destination between input maps schedules
a delete/create pair that can interrupt traffic or fail because the destination
already exists in the table. `create_before_destroy` cannot solve that collision:
AWS allows only one route per physical destination in a table.

1. Create and accept `green` while retaining `blue` and all existing routes.
2. Move the desired destinations to the `green` route-map entries and add state
   moves like these in the same change:

```hcl
moved {
  from = module.vpc.aws_route.cwan_attachment["application/us-east-1a/cwan/blue/10.0.0.0-8"]
  to   = module.vpc.aws_route.cwan_attachment["application/us-east-1a/cwan/green/10.0.0.0-8"]
}
moved {
  from = module.vpc.aws_route.cwan_attachment_ipv6["application/us-east-1a/cwan6/blue/2001:db8:100::-48"]
  to   = module.vpc.aws_route.cwan_attachment_ipv6["application/us-east-1a/cwan6/green/2001:db8:100::-48"]
}
```

3. Verify the full plan updates `core_network_arn` **in place** for every shifted
   route, preserves both attachments, and contains no route creates or destroys.
   Apply that plan and verify connectivity through the intended Cloud WAN policy.
4. Retire `blue` in a later change after all consumers have migrated.

Repeat the moves for every AZ, address family and prefix-list route; shared tables
use `injected/<route_table_key>` in place of `<group>/<az>`. Changing the key is a
Terraform identity operation, even when the two entries select the same ARN; it
does not itself change segment association or override Cloud WAN forwarding rules.

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
- `core_network_attachment_ids`: effective Cloud WAN attachment IDs by key;
- `core_network_attachment_accepter_ids`: managed or injected accepter IDs by key, containing only entries with `accept_attachment = true`;
- `vpc_lattice_service_network_association_id`: effective Lattice association ID;
- `subnet_ids_by_group_by_az` and `route_table_ids_by_group_by_az`: attachment and connectivity subnet composition.

The deprecated scalar TGW output represents only the compatibility adapter and is not the contract for plural attachments.

Deprecated Cloud WAN scalar outputs return a value only when exactly one effective
attachment exists (and, for the accepter, acceptance is selected); otherwise they
return `null`. The v4 full-object `core_network_attachment` output returns a value
only for a created attachment from the embedded adapter. Use plural outputs for
all new consumers.

## Attachment checklist

- Use stable top-level keys for every TGW and Cloud WAN attachment.
- Keep attachment subnet roles and AZ sets consistent with the VPC topology.
- Decide TGW association, propagation, appliance mode, DNS, and security-group referencing explicitly.
- Assign Cloud WAN acceptance to exactly one account and state owner.
- Add Cloud WAN routes only after the attachment no longer requires external acceptance.
- Treat VPC Lattice DNS changes as replacement-sensitive.
