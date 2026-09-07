# Changelog

All notable changes to this module are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.0] - Unreleased

### Added

- Typed top-level contracts for VPC ownership, addressing, Availability Zones, subnets, NAT Gateway, attachments, gateway endpoints, Flow Logs, VPC Lattice, VPC Block Public Access, DHCP options, and tags.
- Caller-keyed secondary IPv4 and IPv6 associations, including static, Amazon-provided, IPAM, and create-or-inject ownership modes.
- Deterministic subnet allocation with explicit AZ CIDRs, calculated netmasks, optional pinned CIDR indices, subnet IPAM, dual-stack, and IPv6-native modes.
- Plural Transit Gateway attachments with caller-owned keys, typed IPv4/IPv6 destination maps, and up to five distinct TGWs per VPC.
- Cloud WAN attachment acceptance controls, generic typed routes, S3 and DynamoDB gateway endpoints, per-group network ACLs, default-resource adoption, Regional VPC Block Public Access, and DHCP option sets.
- Late-bound top-level routes with scalar or AZ-specific targets for composing endpoint-producing modules without dependency cycles.
- Zonal public/private NAT and public Regional NAT with module-created, BYOIP, existing, automatic, and injected address or Gateway ownership options where supported.
- Native CloudWatch Flow Logs destinations and IAM roles, plus externally owned S3 and Kinesis Data Firehose destinations.
- Tier 1 stable composition outputs, a Tier 3 internal-resource escape hatch, thematic contract guides, standardized scenario guides, and a v4-to-v5 migration runbook and reference.

### Changed

- Replaced the v4 flat and loosely typed interface with 14 typed top-level inputs and explicit create-or-inject selectors.
- Made caller-owned map keys durable Terraform state identity for secondary CIDRs, subnet groups, route tables, routes, attachments, endpoints, Flow Logs, exclusions, and ACL rules.
- Co-located subnet role, addressing, route-table ownership, routing, public options, network ACLs, and attachment options under each subnet group.
- Made explicit Availability Zone names and AZ-keyed CIDRs the recommended persistent-environment contract; count-based AZ discovery is development-only.
- Moved NAT configuration to a VPC-wide contract and made subnet groups opt into NAT routing independently.
- Made isolated subnet roles fail closed for Internet, NAT, TGW, Cloud WAN, and generic routes; injected isolated route tables require an explicit caller-responsibility opt-in.
- Split outputs into stable Tier 1 handles, deprecated Tier 2 v4 compatibility aliases, and unstable Tier 3 provider-shaped collections.
- Set `calculated_subnet_az_capacity` to a default of 3 reserved AZ slots per calculated subnet group, matching the most common regional layout; regions with more AZs can raise it up to 6. The value is fixed at creation time: changing it on an existing VPC renumbers calculated subnets.

### Deprecated

- v4-compatible Tier 2 full-object outputs; they remain during 5.x for staged consumer migration and are scheduled for removal in 6.0.
- The singular `subnets[*].transit_gateway_options`, `routing.transit_gateway`, and `routing.transit_gateway_ipv6` adapters; use `transit_gateway_attachments` and keyed plural route maps.
- Pre-release group-keyed output aliases named `*_by_role`; use `*_by_group` or `*_by_semantic_role` outputs.

### Removed

- v4 flat inputs, implicit subnet classification, positional collection identity, and the `optimize_subnet_cidr_ranges` allocation switch.
- The undocumented v4 private-subnet `enable_resource_name_dns_aaaa_record_on_launch` passthrough.
- Module ownership of S3 Flow Logs buckets and Kinesis Data Firehose delivery streams; supply externally governed destination ARNs instead.
- Implicit management of AWS-created default VPC resources; adoption is now explicit and disabled by default.
