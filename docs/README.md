# VPC module documentation

Use these guides to choose and compose the v5 contracts. The root [README](../README.md) remains the starting point for installation, the quick start, and example selection.

## Contract guides

| Guide | Use it for |
| --- | --- |
| [Addressing and Availability Zones](addressing.md) | Primary and secondary CIDRs, IPAM, IPv6, subnet allocation, AZ stability, and caller-owned address keys. |
| [Subnets and routing](subnets-and-routing.md) | Subnet roles, route-table ownership, fail-closed isolation, generic and late-bound zonal routes, and gateway endpoints. |
| [NAT Gateway](nat-gateway.md) | Zonal and Regional NAT placement, public/private connectivity, Elastic IP ownership, and cost trade-offs. |
| [Attachments](attachments.md) | Plural Transit Gateway attachments, Cloud WAN acceptance, VPC Lattice, and destination routing. |
| [Security and operations](security-and-operations.md) | Default-resource adoption, network ACLs, VPC Block Public Access, DHCP options, Flow Logs, and tags. |
| [Outputs](outputs.md) | Stable Tier 1 composition, temporary Tier 2 migration aliases, and the Tier 3 escape hatch. |

## Input map

The module exposes exactly 15 top-level inputs. Start in the guide named in the final column, then use the generated input table in the root README for the complete type and default.

| Input | Responsibility | Guide |
| --- | --- | --- |
| `vpc` | VPC, Internet Gateway, and egress-only Internet Gateway create-or-inject ownership; DNS and tenancy. | [Addressing](addressing.md) |
| `default_resources` | Opt-in adoption and hardening of AWS-created default VPC resources. | [Security and operations](security-and-operations.md) |
| `addressing` | Primary IPv4 and caller-keyed secondary IPv4/IPv6 associations. | [Addressing](addressing.md) |
| `availability_zones` | Explicit production AZ names or development-only count selection. | [Addressing](addressing.md) |
| `calculated_subnet_az_capacity` | Number of AZ slots reserved per calculated subnet group; keep the creation-time value to avoid renumbering established subnets. | [Addressing](addressing.md) |
| `transit_gateway_attachments` | Plural caller-keyed Transit Gateway VPC attachments. | [Attachments](attachments.md) |
| `subnets` | Subnet identity, roles, address allocation, route tables, routes, and network ACLs. | [Subnets and routing](subnets-and-routing.md) |
| `routes` | Late-bound scalar or AZ-specific routes for targets produced by VPC consumers. | [Subnets and routing](subnets-and-routing.md) |
| `nat_gateway` | NAT topology, ownership, connectivity, and Elastic IP sourcing. | [NAT Gateway](nat-gateway.md) |
| `gateway_endpoints` | S3 and DynamoDB gateway endpoint ownership and policy. | [Subnets and routing](subnets-and-routing.md) |
| `flow_logs` | VPC Flow Logs and CloudWatch destination/role ownership. | [Security and operations](security-and-operations.md) |
| `vpc_lattice` | VPC Lattice service-network association and private DNS. | [Attachments](attachments.md) |
| `vpc_block_public_access` | Regional VPC Block Public Access options and exclusions. | [Security and operations](security-and-operations.md) |
| `dhcp_options` | DHCP option-set creation or injection and VPC association. | [Security and operations](security-and-operations.md) |
| `tags` | Global tags inherited by module-created resources. | [Security and operations](security-and-operations.md) |

## Upgrade and migration

- [Upgrade guide 5.0](UPGRADE-GUIDE-5.0.md) is the sequential v4-to-v5 runbook, including plan gates, stop conditions, cleanup, and verification.
- [v4 migration reference](migration-v4-reference.md) contains name formulas, input/output crosswalks, state-address rules, and cases that require import or non-destructive ownership handoff.
- [`migration-from-v4`](../examples/migration-from-v4) provides a caller-root configuration and a catalog of exact `moved` blocks for rehearsal.

## Examples

The root [example catalog](../README.md#examples) compares all 12 configurations by purpose, selection criteria, prerequisites, and cost. Each example README contains a differential configuration excerpt, validation commands, evidence outputs, and a scenario-specific caveat. For centralized PrivateLink naming, hybrid Resolver endpoints, and TGW-connected spokes without Internet egress, start with [`centralized_endpoints_dns`](../examples/centralized_endpoints_dns).
