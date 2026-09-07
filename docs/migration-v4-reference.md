# v4 migration reference

Use this reference with the sequential [v4-to-v5 upgrade guide](UPGRADE-GUIDE-5.0.md). It contains lookup material for configuration translation and state ownership; follow the runbook for ordering, plan gates, cleanup, and rollback decisions.

## Contents

- [v4 Name formula mapping](#v4-name-formula-mapping)
- [Input crosswalk](#input-crosswalk)
- [Output crosswalk](#output-crosswalk)
- [State address rules](#state-address-rules)
- [Cases that cannot use moved](#cases-that-cannot-use-moved)

## v4 Name formula mapping

| Resource | v4 formula | v5 migration setting | Result |
|---|---|---|---|
| VPC | `var.name` | `vpc.name = var.name` | Exact, unchanged. |
| Subnet | `${name_prefix || key}-${az}` | `subnets.<key>.name_prefix` copied; `name_format = "{group}-{az}"` | Exact for every reserved/private group. |
| Route table | `${name_prefix || key}-${az}` | Inherits the subnet `name_format`; leave `route_table_name_format` unset | Exact. Set the route-table field only if v4 was customized out of band. |
| NAT EIP | `nat-${public.name_prefix || "public"}-${az}` | `nat_gateway.subnet_group = "public"`; `name_format = "nat-{group}-{az}"`; leave `eip.name_format` unset | Exact. |
| NAT Gateway | `nat-${public.name_prefix || "public"}-${az}` | Same NAT format | Exact. |
| Internet Gateway | `${var.name}-igw` | `vpc.igw_name_format = "{vpc}-igw"` | Exact; also the v5 default. |
| Egress-only Internet Gateway | `var.name` | `vpc.eigw_name_format = "{vpc}"` | Exact; overrides the native v5 `"{vpc}-eigw"` default. |
| VPC Flow Log | `var.name` | `flow_logs.default.name_format = "{vpc}"` | Exact. |
| Generated CloudWatch log group | no `Name` tag | `flow_logs.default.cloudwatch_options.name_format = ""` | Exact; empty format removes caller `Name` keys. |

The default migration path therefore removes 14 cosmetic updates in the documented
two-AZ topology: six subnets, six route tables, one EIP, and one NAT Gateway. As an
explicit fallback, a team may omit the migration formats and approve exactly those
address-enumerated in-place `Name` tag updates as cosmetic; that fallback must not
broaden the allowlist to replacements or other tag changes.

## Input crosswalk

| v4 variable/path | v5 variable/path | Migration rule |
|---|---|---|
| `name` | `vpc.name` | Copy unchanged. |
| `create_vpc` + `vpc_id` | `vpc.create` + `vpc.id` | Create: keep `create=true` and `id=null`. Existing VPC: set `create=false` and `id`; the ID may be computed upstream. |
| `cidr_block` | `addressing.primary.cidr_block` | Primary CIDR when creating. For v4 secondary-CIDR mode, put it in a stable caller-owned entry such as `addressing.secondary.legacy.ipv4.cidr_block`. |
| `vpc_enable_dns_hostnames` | `vpc.dns.enable_hostnames` | Copy boolean. |
| `vpc_enable_dns_support` | `vpc.dns.enable_support` | Copy boolean. |
| `vpc_instance_tenancy` | `vpc.instance_tenancy` | Copy unchanged. |
| `vpc_ipv4_ipam_pool_id` | `addressing.primary.ipam_pool_id` | Copy with netmask length. |
| `vpc_ipv4_netmask_length` | `addressing.primary.netmask_length` | Convert the v4 string value to a number. |
| `vpc_assign_generated_ipv6_cidr_block` | `addressing.secondary.v4-ipv6.ipv6.amazon_assigned` | Copy as boolean and import the existing association ID as shown above. |
| `vpc_ipv6_cidr_block` | `addressing.secondary.v4-ipv6.ipv6.cidr_block` | Copy unchanged and import the existing association ID. |
| `vpc_ipv6_ipam_pool_id` | `addressing.secondary.v4-ipv6.ipv6.ipam_pool_id` | Copy with netmask length and import the existing association ID. |
| `vpc_ipv6_netmask_length` | `addressing.secondary.v4-ipv6.ipv6.netmask_length` | Convert the v4 string value to a number. |
| `vpc_secondary_cidr` | `addressing.secondary.<key>.ipv4` | Replace the boolean with a stable-keyed entry such as `legacy = { ipv4 = { cidr_block = ... } }`. v5 supports multiple named associations without positional state churn. |
| `vpc_secondary_cidr_natgw` | `nat_gateway.create=false` + `existing_ids` | Convert `{ az = { id = "nat-*" } }` to `{ az = "nat-*" }`; set inject mode plus matching NAT mode/AZ. |
| `az_count` | `availability_zones.count` | Development only. Explicit names are recommended for stable state. |
| `azs` | `availability_zones.names` | Copy unchanged; this is the production migration path. |
| `subnets.<key>.netmask` | `subnets.<key>.ipv4.netmask` | Add `role`; preserve `<key>`. Pin with `cidr_index` or, preferably, migrate with explicit current CIDRs. |
| `subnets.<key>.cidrs` | `subnets.<key>.ipv4.cidrs_by_az` | Build a map from each exact AZ name to its current state CIDR; order is irrelevant. |
| `subnets.<key>.assign_ipv6_cidr` | `subnets.<key>.ipv6.cidrs_by_az` + `auto_assign` + `secondary_cidr_key` | Read each existing `/64` from state, map it to its exact AZ name, set `auto_assign = true`, and select `"v4-ipv6"`. |
| `subnets.<key>.ipv6_cidrs` | `subnets.<key>.ipv6.cidrs_by_az` + `secondary_cidr_key` | Map exact prefixes by AZ name, select `"v4-ipv6"`, and set `auto_assign` to preserve address assignment behavior. |
| `subnets.<key>.ipv6_native` | `subnets.<key>.ipv6.native_only` + `secondary_cidr_key` | Set true, select `"v4-ipv6"`, and provide the existing IPv6 CIDRs keyed by AZ. |
| `subnets.<key>.assign_ipv6_address_on_creation` | `subnets.<key>.ipv6.auto_assign` | Copy boolean; v5 uses the typed IPv6 block. |
| `subnets.<key>.enable_resource_name_dns_aaaa_record_on_launch` | no direct v5 equivalent | Remove. This undocumented v4 private-group passthrough is not part of the v5 contract. |
| `subnets.<key>.name_prefix` | `subnets.<key>.name_prefix` | Copy unchanged; never rename the map key during the first migration. |
| v4 subnet/route-table Name formula | `subnets.<key>.name_format` | Set `"{group}-{az}"`; leave `route_table_name_format` unset so both reproduce v4. |
| v4 NAT/EIP Name formula | `nat_gateway.name_format` / `eip.name_format` | Set NAT to `"nat-{group}-{az}"`; EIP inherits it. |
| v4 IGW/EIGW Name formulas | `vpc.igw_name_format` / `vpc.eigw_name_format` | Set `"{vpc}-igw"` / `"{vpc}"`. |
| `subnets.<key>.tags` | `subnets.<key>.tags` | Copy unchanged. |
| implicit key class | `subnets.<key>.role` | `public` -> `public`; `transit_gateway` -> `transit_gateway`; `core_network` -> `core_network`; every other v4 key -> normally `private` (use `isolated` after removing Internet/NAT/transit routes; S3/DynamoDB gateway endpoint routes are allowed). |
| `subnets.public.connect_to_igw` | `subnets.public.routing.internet_gateway` | Copy boolean; null still defaults true for the public role. |
| `subnets.public.map_public_ip_on_launch` | `subnets.public.public_options.map_public_ip` | Copy boolean when true. Both v4 and v5 default to `false`, so omission preserves behavior. |
| `subnets.public.nat_gateway_configuration` | `nat_gateway.mode` | Copy `none`, `single_az`, or `all_azs`. For `single_az`, set `nat_gateway.az` to the v4 first AZ explicitly. |
| `subnets.<private>.connect_to_public_natgw` | `subnets.<private>.routing.nat_gateway` | Copy boolean. |
| `subnets.<private>.connect_to_eigw` | `subnets.<private>.routing.egress_only_igw` | Copy boolean. |
| `vpc_egress_only_internet_gateway` | `subnets[*].routing.egress_only_igw` + `vpc.eigw_create`/`eigw_id` | Copy routing intent. Keep create mode for a moved v4 EIGW; use `eigw_create=false` plus ID only when ownership moves outside this module. |
| `subnets.transit_gateway.connect_to_public_natgw` | `subnets.transit_gateway.routing.nat_gateway` | v4 accepts a bool in implementation; copy as boolean. |
| `subnets.transit_gateway.transit_gateway_default_route_table_association` | `subnets.transit_gateway.transit_gateway_options.default_route_table_association` | Copy boolean. |
| `subnets.transit_gateway.transit_gateway_default_route_table_propagation` | `subnets.transit_gateway.transit_gateway_options.default_route_table_propagation` | Copy boolean. |
| `subnets.transit_gateway.transit_gateway_appliance_mode_support` | `subnets.transit_gateway.transit_gateway_options.appliance_mode_support` | Convert `"enable"`/`"disable"` to boolean. |
| `subnets.transit_gateway.transit_gateway_dns_support` | `subnets.transit_gateway.transit_gateway_options.dns_support` | Convert `"enable"`/`"disable"` to boolean. |
| `subnets.transit_gateway.transit_gateway_security_group_referencing_support` | `subnets.transit_gateway.transit_gateway_options.security_group_referencing` | Convert `"enable"`/`"disable"` to boolean. |
| `transit_gateway_id` | `subnets.transit_gateway.transit_gateway_options.id` | Move under the attachment subnet group. |
| `transit_gateway_routes.<group>` | `subnets.<group>.routing.transit_gateway` | Wrap the single CIDR/prefix-list ID in a list. |
| `transit_gateway_ipv6_routes.<group>` | `subnets.<group>.routing.transit_gateway_ipv6` | Wrap the single destination in a list. |
| `subnets.core_network.connect_to_public_natgw` | `subnets.core_network.routing.nat_gateway` | Copy boolean. |
| `subnets.core_network.appliance_mode_support` | `subnets.core_network.core_network_options.appliance_mode` | Copy boolean. |
| `subnets.core_network.require_acceptance` | `subnets.core_network.core_network_options.require_acceptance` | Copy boolean. |
| `subnets.core_network.accept_attachment` | `subnets.core_network.core_network_options.accept_attachment` | Copy boolean; cross-account acceptance remains external. |
| `core_network.id` / `core_network.arn` | `subnets.core_network.core_network_options.id` / `.arn` | Move under the attachment subnet group. |
| `core_network_routes.<group>` | `subnets.<group>.routing.core_network` | Wrap the single destination in a list. |
| `core_network_ipv6_routes.<group>` | `subnets.<group>.routing.core_network_ipv6` | Wrap the single destination in a list. |
| `vpc_flow_logs` | `flow_logs.default` | Use stable key `default`; the remaining rows map every field. |
| v4 Flow Log `Name = var.name` | `flow_logs.default.name_format` | Set `"{vpc}"`; the v5 default includes the map key and would update the tag. |
| v4 generated log group without `Name` | `flow_logs.default.cloudwatch_options.name_format` | Set `""` to omit the tag independently from the Flow Log. |
| `vpc_flow_logs.name_override` or v4 generated log-group name | `flow_logs.default.cloudwatch_options.name` + declarative import ID | Set the exact physical `name` reported by `terraform state show`, not merely the old prefix. Use the root `removed { destroy=false }` + `import` handoff shown above. |
| v4 generated CloudWatch IAM role `name_prefix` | `flow_logs.default.role_name_prefix` | Copy the exact `name_prefix` reported by state (not the generated role `name`) before applying the IAM role moved block. |
| `vpc_flow_logs.log_destination` | `flow_logs.default.create_destination=false` + `destination_arn` | CloudWatch injection sets the explicit flag; S3/Firehose remain externally managed and always require the ARN. |
| `vpc_flow_logs.iam_role_arn` | `flow_logs.default.create_iam_role=false` + `iam_role_arn` | Set both for CloudWatch role injection; keep `create_iam_role=true` to create the v5 role. |
| `vpc_flow_logs.kms_key_id` | `flow_logs.default.cloudwatch_options.kms_key_id` | Copy for CloudWatch. S3/Firehose encryption belongs to the external destination. |
| `vpc_flow_logs.log_destination_type` | `flow_logs.default.destination_type` | Map `cloud-watch-logs` -> `cloudwatch`, `s3` -> `s3`; `none` -> omit/disable the map entry. v5 additionally supports `kinesis`. |
| `vpc_flow_logs.log_format` | `flow_logs.default.log_format` | Copy unchanged. |
| `vpc_flow_logs.retention_in_days` | `flow_logs.default.cloudwatch_options.retention_in_days` | Copy for CloudWatch. |
| `vpc_flow_logs.log_bucket_lifecycle_filter_prefix` | no direct v5 equivalent | S3 lifecycle is owned by the external bucket/logging module. |
| `vpc_flow_logs.tags` | `flow_logs.default.tags` | Copy unchanged. |
| `vpc_flow_logs.traffic_type` | `flow_logs.default.traffic_type` | Copy `ALL`, `ACCEPT`, or `REJECT`. |
| `vpc_flow_logs.destination_options.file_format` | `flow_logs.default.s3_options.file_format` | Copy for S3. |
| `vpc_flow_logs.destination_options.hive_compatible_partitions` | `flow_logs.default.s3_options.hive_compatible_partitions` | Copy for S3. |
| `vpc_flow_logs.destination_options.per_hour_partition` | `flow_logs.default.s3_options.per_hour_partition` | Copy for S3. |
| `vpc_lattice.service_network_identifier` | `vpc_lattice.enabled=true` + `service_network_identifier` | Enable explicitly, then copy the identifier; it may be computed upstream. |
| `vpc_lattice.security_group_ids` | `vpc_lattice.security_group_ids` | Convert list to set semantics (ordering is ignored). |
| `vpc_lattice.private_dns_enabled` | `vpc_lattice.private_dns_enabled` | Copy explicitly. When true, `dns_options.private_dns_preference` defaults to AWS's `VERIFIED_DOMAINS_ONLY`; choose a specified-domain mode and provide 1-10 domains only when required. DNS option changes replace the association. |
| `vpc_lattice.tags` | `vpc_lattice.tags` | Copy unchanged. |
| `optimize_subnet_cidr_ranges` | no direct equivalent | Removed. v5 uses explicit AZ-keyed CIDRs (recommended) or deterministic netmask allocation with optional `cidr_index`. |
| `tags` | `tags` | Copy unchanged. Keep provider `default_tags` unchanged; effective precedence is provider defaults < global tags < group/resource tags < generated Name. |

## Output crosswalk

| v4 output | v5 migration target | Shape/notes |
|---|---|---|
| `vpc_attributes` | Tier 2 `vpc_attributes`; then Tier 1 `vpc_id`, `vpc_arn`, `vpc_cidr_block` | Tier 2 remains a full provider object. |
| `azs` | Tier 1 `azs` | Exact `list(string)`. |
| `transit_gateway_attachment_id` | Tier 1 `transit_gateway_attachment_ids["vpc"]` | Use the keyed map for new consumers. The deprecated scalar output preserves the exact v4 scalar/null shape only as a temporary v5 migration adapter. |
| `core_network_attachment` | Tier 2 `core_network_attachment`; then Tier 1 `core_network_attachment_id` | Tier 2 remains the full object. |
| `private_subnet_attributes_by_az` | Tier 2 same name; then `subnet_ids_by_group_by_az` / `subnet_cidrs_by_group_by_az` | Exact composite keys `<group>/<az>` in Tier 2. |
| `public_subnet_attributes_by_az` | Tier 2 same name; then group/semantic Tier 1 subnet outputs | Exact AZ keys when the group remains named `public`. |
| `tgw_subnet_attributes_by_az` | Tier 2 same name; then group/semantic Tier 1 subnet outputs | Exact AZ keys when the group remains named `transit_gateway`. |
| `core_network_subnet_attributes_by_az` | Tier 2 same name; then group/semantic Tier 1 subnet outputs | Exact AZ keys when the group remains named `core_network`. |
| `rt_attributes_by_type_by_az` | Tier 2 same name; then Tier 1 route-table ID outputs | Exact outer keys; `private` retains `<group>/<az>`, reserved groups retain AZ keys. |
| `nat_gateway_attributes_by_az` | Tier 2 same name; then `nat_gateway_ids`, `nat_public_ips`, `nat_private_ips`, `nat_eip_allocation_ids` | Tier 2 rekeys v5 `nat/<az>` objects back to AZ. |
| `natgw_id_per_az` | Tier 2 same name; then `nat_gateway_ids` | Exact `{ az = { id = string } }`; single-AZ IDs are duplicated across AZs. |
| `internet_gateway` | Tier 2 same name; then `internet_gateway_id` | Tier 2 full object for module-created IGW. |
| `egress_only_internet_gateway` | Tier 2 same name; then `egress_only_igw_id` | Tier 2 full object. |
| `vpc_lattice_service_network_association` | Tier 2 same name; then Tier 1 association ID | Tier 2 full object. |
| `flow_log_attributes` | Tier 2 same name; then `flow_log_ids["default"]` | Tier 2 selects key `default` or the only configured Flow Log. |

## State address rules

`moved` blocks are exact and static. v4 used AZ-only keys for reserved subnet types and NAT, composite `<private-group>/<az>` keys for private subnets, and `count` index `[0]` for attachments. v5 uses:

- subnets, route tables, associations: `<group>/<az>`;
- EIPs/NAT: `nat/<az>`;
- TGW/CWAN attachments and Lattice: `"vpc"`;
- Flow Logs: caller key, conventionally `"default"`;
- routes: `<group>/<az>/<target>` plus a destination suffix for TGW/CWAN.

The [`moved.tf`](../examples/migration-from-v4/moved.tf) catalog contains 63 exact mappings for the union of the documented two-AZ topology. It is a catalog, not a required move count. Select only sources present in `terraform state list`, repeat each per-AZ block for the real AZ set and each private group, and omit entire feature sections (TGW, Core Network, EIGW, Lattice, extra NAT AZs/routes) when absent. Destination key suffixes use `replace(destination, "/", "-")` (for example `10.0.0.0/8` -> `10.0.0.0-8`). `aws_vpc.main[0]` and `aws_internet_gateway.main[0]` keep their address and need no block. In v4.8.0, move `module.vpc.module.flow_logs[0].aws_flow_log.main` and `module.vpc.module.flow_logs[0].aws_iam_role.flow_logs[0]`; the CloudWatch log group uses the declarative forget/import handoff instead of a moved block.

A v4 secondary association moves as follows when that mode is used:

```hcl
moved {
  from = module.vpc.aws_vpc_ipv4_cidr_block_association.secondary[0]
  to   = module.vpc.aws_vpc_ipv4_cidr_block_association.secondary["legacy"]
}
```

Configure the matching contract key before the move:

```hcl
addressing = {
  primary = { cidr_block = "10.42.0.0/16" }
  secondary = {
    legacy  = { ipv4 = { cidr_block = "100.64.0.0/16" } }
    v4-ipv6 = { ipv6 = { amazon_assigned = true } }
  }
}
```

A subnet that consumes this range sets `ipv4.secondary_cidr_key = "legacy"`;
that selector establishes the association dependency for a normal apply.

## Cases that cannot use `moved`

| v4 state | v5 disposition | Why / workaround |
|---|---|---|
| v4 IPv6 association embedded in `module.vpc.aws_vpc.main[0]` | `module.vpc.aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"]` | Capture the association identity and declaratively import it at the standalone v5 address. An embedded VPC attribute cannot be the source of a `moved` block. The v5 resource's `ignore_changes` bridge must preserve all four legacy embedded IPv6 fields; reject any plan that updates IPv6 on `aws_vpc.main[0]`. With that bridge, the import transfers state ownership without disassociating the live prefix. |
| `module.vpc.module.flow_logs[0].aws_cloudwatch_log_group.main[0]` | `module.vpc.aws_cloudwatch_log_group.flow_logs["default"]` | Capture the generated `name`, configure it as `cloudwatch_options.name`, forget the old address with `removed { destroy=false }`, and import that name at the v5 address in the same plan. A direct move can converge after provider-6.x refresh, but the declarative handoff makes ownership explicit and independently refreshes the final address. |
| `module.vpc.module.flow_logs[0].aws_iam_role.flow_logs[0]` | `module.vpc.aws_iam_role.flow_logs["default"]` | Keep the moved block, but first configure `role_name_prefix` with the exact v4 state `name_prefix`. Trust policy, description, and tags may update in place; the role ID and generated name must not change. |
| `module.vpc.module.flow_logs[0].aws_iam_role_policy.flow_logs[0]` | no direct move | v4.8.0 uses an inline policy whose identity and document differ from the v5 inline policy. Forget it with the unindexed `removed { destroy=false }` address, let v5 create `publish-vpc-flow-logs`, verify new log delivery, then delete the captured v4 inline-policy name from the preserved role. |
| v4-created S3 Flow Log bucket and its public-access, encryption, and lifecycle resources | caller-owned logging module/resource | v5 intentionally does not own durable S3/Firehose destinations. Move same-type resources with `terraform state mv` into a new caller-owned logging resource/module address, or import them there, then pass the bucket ARN as `flow_logs.default.destination_arn`. Do not allow Terraform to destroy a log archive. |
| Any address whose destination is an injected ID (`vpc.create=false`, `vpc.igw_create=false`, `nat_gateway.create=false`, `subnets[*].manage_route_table=false`) | no managed destination resource | Injection removes lifecycle ownership; the paired ID fields may be computed. First establish ownership in the destination configuration, then use a declarative `removed { destroy=false }` handoff so the normal plan proves that the physical object is retained. |
| Route whose v4 destination or v5 route list changed during migration | no safe one-to-one block | Freeze destinations for the migration. If already changed, import the AWS route into the final v5 address where supported, or allow a reviewed delete/create during a maintenance window. |

`terraform state mv` is appropriate only when source and destination have the same resource type. Prefer declarative `moved` blocks for repeatability and retain them until every workspace has applied the upgrade.
