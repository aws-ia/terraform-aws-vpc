# Addressing and Availability Zones

The addressing contract separates VPC-level CIDR ownership from subnet allocation. Stable caller keys and explicit AZ names are the strongest controls against unintended address or state movement.

## VPC and gateway ownership

`vpc.create` is the plan-known ownership selector:

- `create = true` requires `id = null` and lets the module own the VPC.
- `create = false` requires a non-empty `id` and injects an existing VPC.
- `igw_create`/`igw_id` and `eigw_create`/`eigw_id` apply the same create-or-inject rule to Internet Gateways and egress-only Internet Gateways.

Explicit booleans decide collection cardinality, so injected IDs may be computed by upstream resources or modules. An injected resource keeps its existing lifecycle owner; this module only manages dependent resources and routes selected by its inputs.

For an existing VPC, use an empty primary object because the module observes the VPC's primary IPv4 CIDR:

```hcl
vpc = {
  name   = "shared-vpc"
  create = false
  id     = module.network_foundation.vpc_id
}

addressing = {
  primary = {}
}
```

## Primary and secondary VPC CIDRs

The primary block accepts one IPv4 source:

| Mode | Fields |
| --- | --- |
| Static | `cidr_block` |
| IPAM | `ipam_pool_id` and `netmask_length` |
| Existing VPC | Empty object |

Every `addressing.secondary` entry configures exactly one address family. The map key is durable Terraform state identity, not a display label:

```hcl
addressing = {
  primary = { cidr_block = "10.0.0.0/16" }
  secondary = {
    shared-services = {
      ipv4 = { cidr_block = "100.64.0.0/20" }
    }
    amazon-ipv6 = {
      ipv6 = { amazon_assigned = true }
    }
  }
}
```

Renaming `shared-services` or `amazon-ipv6` changes the keyed resource address. Preserve keys after deployment or provide caller-root `moved` blocks for every affected address.

Secondary associations support create or inject ownership:

- create mode requires exactly one valid static, IPAM, or Amazon-provided source;
- inject mode uses `create = false` plus `association_id` and omits source-allocation fields;
- one physical association ID cannot appear under multiple keys.

IPv6 associations are always secondary. Amazon assignment and IPAM allocation are mutually exclusive; IPAM prefixes must be `/44`, `/48`, `/52`, `/56`, or `/60`.

## Availability Zone identity

Use explicit AZ names for persistent environments:

```hcl
availability_zones = {
  names = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
```

`availability_zones.count` selects the first AZ names returned alphabetically and is intended only for development. A newly available AZ that sorts earlier can change the selected set, and data-source-derived names can defer related preconditions until apply.

AZ order is part of identity for calculated address plans. When migrating or expanding, preserve the existing order and append new AZs rather than reconstructing the list.

## Subnet IPv4 allocation

Each subnet group selects exactly one IPv4 mode:

| Mode | Configuration | Stability |
| --- | --- | --- |
| Explicit | `cidrs_by_az` | Strongest: each AZ is bound to an exact CIDR. |
| Calculated | `netmask`, optionally `cidr_index` | Deterministic; pin groups that must not move. |
| IPAM | `ipam_pool_id` and `netmask_length` | CIDR may remain unknown until apply. |

Calculated allocation reserves three AZ slots per group by default (`calculated_subnet_az_capacity`, raisable to six). A pinned `cidr_index` is an absolute group slot and does not move when other groups or AZs are added. Unpinned groups pack largest-first and then alphabetically, so adding or removing an earlier group can move later unpinned ranges.

`ipv4.secondary_cidr_key` selects the parent secondary IPv4 association. Omitting it selects the primary VPC CIDR.

## Subnet IPv6 allocation

Every IPv6 subnet block must select its parent with `secondary_cidr_key`. It then uses one allocation mode:

- explicit `/64` values in `cidrs_by_az`;
- subnet IPAM with `ipam_pool_id` and `netmask_length = 64`;
- automatic `/64` calculation with `auto_assign = true`, optionally pinned by `cidr_index`.

Set `native_only = true` only when the subnet group omits IPv4 entirely. `auto_assign` controls assignment of IPv6 addresses to newly created network interfaces; it does not create general internet reachability.

```hcl
subnets = {
  application = {
    role = "private"
    ipv4 = { netmask = 24, cidr_index = 0 }
    ipv6 = {
      secondary_cidr_key = "amazon-ipv6"
      auto_assign        = true
      cidr_index         = 0
    }
  }
}
```

## IPAM planning boundary

The module validates field combinations, selected parent keys, known CIDR overlap, and known subnet containment. It cannot prove every relationship between VPC pools and subnet pools during planning because AWS can return pool allocation and ancestry data only during provider operations.

Treat an AWS IPAM allocation or scope error as an address-plan failure. Correct the pool hierarchy or sharing policy; do not force state or replace the stable caller keys.

## Addressing checklist

- Use explicit AZ names and explicit `cidrs_by_az` for the strongest production immutability.
- Preserve `addressing.secondary` and `subnets` map keys after deployment.
- Pin calculated IPv4 and IPv6 groups with `cidr_index` when their ranges must survive topology growth.
- Select every IPv6 parent explicitly with `secondary_cidr_key`.
- Keep create-or-inject ownership separate from physical IDs.
- Expect IPAM-assigned CIDRs to be unknown until apply and verify pool ancestry outside Terraform when necessary.
