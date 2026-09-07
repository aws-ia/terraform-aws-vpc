# NAT Gateway

NAT topology is a VPC-wide decision, while each subnet group independently decides whether to route through it. Choose placement, connectivity, and address ownership before enabling `subnets.<group>.routing.nat_gateway`.

## Mode selection

| Mode | Placement | Availability and cost profile | Required fields |
| --- | --- | --- | --- |
| `none` | No NAT Gateway | No NAT hourly or processing charge. | None. |
| `single_az` | One zonal Gateway | Lowest Gateway count; every consumer depends on one AZ and may incur cross-AZ transfer. | `az`; public or private host `subnet_group`. |
| `all_azs` | One zonal Gateway per selected AZ | AZ-local routing and independent zonal Gateways; one Gateway-hour per AZ. | Compatible host `subnet_group`. |
| `regional` | One public VPC-level Regional NAT Gateway | AWS maintains active-AZ address placement; billed per active AZ rather than as one discounted Gateway. | No `az` or `subnet_group`; public connectivity only. |

`single_az` and `all_azs` support public or private NAT. Regional NAT is public only and does not use a host subnet group.

```hcl
nat_gateway = {
  mode = "regional"
}
```

For zonal NAT, if `subnet_group` is omitted, the module selects the first compatible group alphabetically. Set it explicitly in persistent configurations so adding another public or private group cannot change placement.

## Public and private NAT

Public NAT requires a public subnet group and Internet Gateway routing. Private NAT requires a private subnet group, creates no public Elastic IP, and is intended for translation before private connectivity such as a Transit Gateway.

```hcl
nat_gateway = {
  mode              = "all_azs"
  connectivity_type = "private"
  subnet_group      = "nat-host"
}
```

Private NAT does not create internet reachability. Its host route tables must forward the required private destinations to an attachment or other private target, and the remote domain must return traffic to the translated range.

## Elastic IP ownership

| `eip.mode` | Zonal NAT | Regional NAT | Lifecycle owner |
| --- | --- | --- | --- |
| `create` | Module creates one ordinary EIP per Gateway. | AWS automatically manages public IPs and active-AZ placement; no child EIP resources are created. | Module for zonal EIPs; AWS Regional NAT service for automatic addresses. |
| `byoip_pool` | Module allocates one EIP per Gateway from `public_ipv4_pool`. | Module allocates one EIP per configured AZ and passes manual address blocks. | Module owns the EIP allocations; caller owns the BYOIP pool. |
| `existing` | Caller supplies allocation IDs keyed by NAT AZ. | Caller supplies allocation IDs for every configured AZ and the module passes manual address blocks. | Caller; destroy does not release injected EIPs. |

Changing a Regional NAT Gateway between automatic address management and manual address blocks replaces the Gateway under provider semantics. Review the plan as an egress cutover.

## NAT resource injection

Set `create = false` with `existing_ids` to use NAT Gateways owned elsewhere. Zonal injection uses selected AZ keys; Regional injection uses exactly `regional`:

```hcl
nat_gateway = {
  mode   = "regional"
  create = false
  existing_ids = {
    regional = module.network_foundation.regional_nat_gateway_id
  }
}
```

The module may create routes to injected IDs but does not manage the injected Gateway or its addresses.

## Regional NAT behavior

Regional NAT follows network-interface presence across AZs, preserves zonal affinity after capacity is active, and removes the need for public NAT-host subnets. The module returns the same VPC-level Gateway ID under each configured AZ key so downstream Tier 1 route and output shapes remain stable. `regional_nat_gateway_route_table_id` exposes the AWS-managed route table when the module creates the Gateway.

Regional mode is an operational simplification, not an hourly-cost reduction. AWS charges for every active AZ, including AZs that remain active because network interfaces are present. AZ expansion commonly takes 15–20 minutes and can take up to 60 minutes; traffic may cross AZs and incur transfer charges while expansion completes.

During Regional NAT destroy, the provider can report `Plugin did not respond` while AWS continues deleting asynchronously; retrying the destroy converges.

Use manual BYOIP or existing addresses when external allowlists require deterministic public IPv4 values. Use automatic `eip.mode = "create"` when AWS-managed address and AZ lifecycle is acceptable.

## Routing and DNS64

A subnet group opts into IPv4 NAT routing with `routing.nat_gateway = true`. In `all_azs` mode each managed route table selects the same-AZ Gateway. A shared injected route table cannot express per-AZ targets and is therefore incompatible with `all_azs` NAT for a referencing group.

`routing.dns64 = true` also creates a `64:ff9b::/96` route through NAT and requires a compatible public NAT path. DNS64 synthesizes AAAA responses; the NAT route supplies translation for IPv4-only destinations. An egress-only Internet Gateway alone is not NAT64.

## Operational checklist

- Model the outage and cross-AZ-transfer impact of `single_az` before using it beyond development.
- Use explicit NAT host groups and preserve their subnet keys.
- Verify address ownership before destroy or mode changes.
- Treat automatic/manual Regional address transitions as replacement events.
- Monitor Regional active-AZ expansion before assuming zonal affinity.
- Include Gateway-hour, processing, public IPv4, cross-AZ, and downstream transfer charges in cost estimates.
