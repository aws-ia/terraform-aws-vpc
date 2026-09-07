<!-- BEGIN_TF_DOCS -->
# AWS VPC Terraform module

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-aws--ia%2Fvpc-844FBA?logo=terraform)](https://registry.terraform.io/modules/aws-ia/vpc/aws/latest)
[![CI](https://github.com/aws-ia/terraform-aws-vpc/actions/workflows/ci.yml/badge.svg)](https://github.com/aws-ia/terraform-aws-vpc/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/aws-ia/terraform-aws-vpc)](LICENSE)

This module creates and composes Amazon VPC topologies from typed subnet groups.
It provides deterministic IPv4 and IPv6 allocation, stable `"<group>/<az>"`
resource identity, explicit create-or-inject ownership, native Flow Logs, and
semver-defined output tiers.

> [!IMPORTANT]
> Upgrading from v4? Follow the [5.0 upgrade guide](docs/UPGRADE-GUIDE-5.0.md)
> before changing configuration or state. It provides a declarative
> `moved`/`removed`/`import` path designed to avoid resource replacement.

## Navigation

- [Key capabilities](#key-capabilities)
- [Usage](#usage)
- [Documentation](#documentation)
- [Examples](#examples)
- [Design contracts](#design-contracts)
- [NAT Gateway modes](#nat-gateway-modes)
- [Security and cost controls](#security-and-cost-controls)
- [Inputs](#inputs)
- [Outputs](#outputs)

## Key capabilities

- **Typed subnet groups:** model public, private, isolated, Transit Gateway, and
  Cloud WAN roles without coupling group names to effective connectivity.
- **Stable addressing:** use explicit CIDRs, VPC IPAM, or deterministic calculated
  ranges with optional `cidr_index` pinning.
- **IPv4 and IPv6:** create dual-stack and IPv6-native subnets, DNS64/NAT64 routes,
  and egress-only Internet Gateway routing.
- **Explicit ownership:** create resources or inject existing VPC, gateway, subnet,
  route-table, NAT, attachment, endpoint, Flow Log, DHCP, BPA, and Lattice boundaries.
- **Composable routing:** add static or AZ-specific late-bound routes to targets
  produced by modules that consume VPC subnet and route-table outputs.
- **Operational controls:** configure zonal or Regional NAT, gateway endpoints,
  Flow Logs, Network ACLs, and opt-in management of default VPC resources.
- **Composable outputs:** consume semver-protected IDs, CIDRs, ARNs, and maps by
  group, semantic role, and Availability Zone.

## Usage

> [!NOTE]
> For production, use explicit Availability Zone names and CIDRs, or pinned
> `cidr_index` values, so future topology changes do not change resource identity.

> [!WARNING]
> Applying this example creates a public NAT Gateway and incurs hourly and
> data-processing charges. Cross-AZ traffic can add transfer charges.
> `terraform init` alone creates no AWS resources.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = "~> 5.0"

  vpc = {
    name = "application-vpc"
  }

  addressing = {
    primary = { cidr_block = "10.20.0.0/16" }
  }

  availability_zones = {
    names = ["us-east-1a", "us-east-1b"]
  }

  subnets = {
    public = {
      role           = "public"
      ipv4           = { cidrs_by_az = { "us-east-1a" = "10.20.0.0/24", "us-east-1b" = "10.20.1.0/24" } }
      public_options = { map_public_ip = true }
    }

    application = {
      role    = "private"
      ipv4    = { cidrs_by_az = { "us-east-1a" = "10.20.10.0/24", "us-east-1b" = "10.20.11.0/24" } }
      routing = { nat_gateway = true }
    }
  }

  nat_gateway = {
    mode = "regional"
  }
}
```

## Documentation

- [Documentation map](docs/README.md) — choose a guide by task or input.
- [Addressing and Availability Zones](docs/addressing.md) — static CIDRs, IPAM,
  IPv6, parent selection, and stable allocation.
- [Subnets and routing](docs/subnets-and-routing.md) — roles, route tables, NAT,
  endpoints, custom routes, and Network ACLs.
- [NAT Gateway](docs/nat-gateway.md) — placement, address ownership, Regional NAT,
  and cost trade-offs.
- [Transit, Cloud WAN, and VPC Lattice](docs/attachments.md) — attachment ownership,
  acceptance, and route targeting.
- [Security and operations](docs/security-and-operations.md) — Flow Logs, default
  resources, VPC Block Public Access, DHCP, naming, and tags.
- [Outputs and composition](docs/outputs.md) — stable handles and compatibility tiers.
- [5.0 upgrade guide](docs/UPGRADE-GUIDE-5.0.md) — production migration runbook.

## Examples

| Example | What it demonstrates | Choose it when | External prerequisites and cost |
|---|---|---|---|
| [`basic`](examples/basic) | Three-AZ web topology with public, private, and isolated groups; dual stack; NAT64; gateway endpoints; and Flow Logs. | You want the smallest deployable tour of the contract. | Creates one NAT Gateway and CloudWatch Logs resources. Uses development-only AZ count selection. |
| [`enterprise`](examples/enterprise) | Explicit production AZs/CIDRs, a secondary IPv4 range, dual-stack and isolated tiers, tier-specific Network ACLs, S3/DynamoDB gateway endpoints, Regional NAT, Flow Logs, and VPC Lattice. | You need an enterprise multi-tier starting point with explicit stateless boundaries and private AWS service routes. | Creates one Regional NAT Gateway billed across three active AZs, CloudWatch Logs, and VPC Lattice resources; gateway endpoints have no hourly endpoint charge. |
| [`hub`](examples/hub) | Multiple public groups, AZ-specific routes to existing GWLB endpoints, pinned IPv4/IPv6 ranges, two TGW attachments, Cloud WAN, external Firehose, existing NAT EIPs, and a private-NAT inspection VPC. | You are composing an advanced network hub with zonal service insertion. | Requires TGW, peering, GWLB endpoint, Core Network, EIP, and Firehose identifiers. Creates billable NAT and attachment resources. |
| [`nat_byoip`](examples/nat\_byoip) | Zonal NAT with created, BYOIP, and existing EIPs, plus Regional NAT with manual existing addresses. | You are choosing NAT address ownership or evaluating Regional NAT. | BYOIP/existing modes require real pool/allocation IDs. Creates multiple billable NAT Gateways. |
| [`ipam`](examples/ipam) | Primary and secondary IPv4 IPAM, IPv6 IPAM, subnet pools, dual-stack groups, and IPv6-native subnets. | Your address plan is managed by VPC IPAM. | Requires an existing, shared hierarchy of VPC and subnet IPAM pools. |
| [`dual_stack`](examples/dual\_stack) | Caller-keyed IPv6 parent selection, dual-stack and IPv6-native groups, EIGW, DNS64/NAT64, and pinned IPv6 indices. | IPv6 behavior is the focus of your design. | Creates one Regional NAT Gateway billed across active AZs. |
| [`existing_vpc`](examples/existing\_vpc) | Injection of a computed VPC, IGW, shared route table, and EIPs while the module owns subnets, associations, routes, and Regional NAT. | You are composing with a network foundation stack. | Self-contained example creates the injected resources and one billable Regional NAT Gateway. |
| [`secure_isolated`](examples/secure\_isolated) | Bidirectional VPC Block Public Access, DHCP options, adoption of default resources, per-group NACLs, and no Internet/transit routing. | You need an isolated enclave or want to evaluate opt-in security controls. | Changes an account/Region BPA singleton; coordinate ownership. |
| [`private_nat`](examples/private\_nat) | Private NAT for overlapping address space, a secondary translation CIDR, and TGW routing without IGW/EIPs. | Workload CIDRs overlap a remote TGW domain. | Requires an existing TGW ID. Private NAT Gateways are billable. |
| [`inspection_egress`](examples/inspection\_egress) | Centralized TGW inspection, appliance mode, AZ-local firewall/NAT routing, prefix-list return routes, and Network Firewall composition inputs. | You are building centralized inspected Internet egress. | Requires a TGW ID and prefix list. Creates three NAT Gateways and a TGW attachment; Network Firewall is opt-in. |
| [`migration-from-v4`](examples/migration-from-v4) | State-oriented major-version migration skeleton with stable names, compatibility outputs, declarative handoff, and zero-destroy checks. | You are upgrading an existing deployment. | Never apply unchanged; rehearse against copied real state and follow the upgrade guide. |
| [`centralized_endpoints_dns`](examples/centralized\_endpoints\_dns) | Two-AZ hub and spokes with centralized interface endpoints, Route 53 Profiles, hybrid Resolver, private zones, RAM sharing, and explicit TGW return routing. | You need centralized PrivateLink DNS and bidirectional hybrid name resolution without Internet egress. | Creates a TGW, three attachments, ten endpoint ENIs, four Resolver ENIs, Route 53 resources, and RAM shares. |

Examples with external dependencies validate identifier shape, but only real IDs,
ARNs, pools, and account ownership make them deployable. Review each example README
before `terraform apply`.

## Design contracts

- **State identity:** subnet-group keys and injected `route_table_key` values are
  durable Terraform identity. Renames require caller-owned `moved` blocks;
  `name_prefix` changes display names without changing addresses.
- **Addressing:** explicit `cidrs_by_az` is the production default. IPAM preserves
  central allocation, while calculated `netmask` is deterministic scaffolding;
  pin `cidr_index` for groups that must not move. IPv6 subnets are always `/64`.
- **Connectivity:** role and effective routing are independent. Use
  `subnet_connectivity_by_group_by_az` rather than inferring access from names.
- **Ownership:** plan-known `create` and `enabled` selectors define ownership;
  resource IDs and ARNs may come from upstream resources or modules.

See [Addressing and Availability Zones](docs/addressing.md) and
[Subnets and routing](docs/subnets-and-routing.md) for invariants, replacement
boundaries, and create-or-inject patterns.

## NAT Gateway modes

| Mode | Placement | Best fit | Key trade-off |
|---|---|---|---|
| `none` | No NAT Gateway | Isolated or externally routed workloads | No managed IPv4 Internet egress. |
| `single_az` | One zonal NAT Gateway | Development or an explicitly accepted single-AZ dependency | Lowest gateway count; cross-AZ transfer and zonal dependency. |
| `all_azs` | One zonal NAT Gateway per configured AZ | Zonal production egress and private NAT | Requires compatible host subnets; public mode typically uses one EIP per AZ. |
| `regional` | One public VPC-level resource with AZ-aware capacity | Public egress without public NAT host subnets | Billed per active AZ; automatic/manual address mode changes replace the resource. Private NAT is unsupported. |

> [!WARNING]
> Regional NAT is an operational simplification, not an hourly-cost reduction.
> AWS charges one NAT Gateway-hour per active AZ, and expansion can temporarily
> introduce cross-AZ traffic and transfer charges.

For EIP ownership, automatic versus manual Regional NAT, BYOIP, existing addresses,
and full output shapes, see [`examples/nat_byoip`](examples/nat\_byoip).
`nat_gateway_ids` remains keyed by configured AZ; Regional mode repeats the same
VPC-level ID to preserve that stable Tier 1 shape.

## Security and cost controls

- `default_resources` can adopt the AWS-created default security group, network
  ACL, and route table. Every selector defaults to `false`; reading their Tier 1
  IDs does not adopt lifecycle ownership.
- Per-group Network ACLs are typed and keyed by AWS rule number. They are stateless,
  so configure reverse paths and ephemeral ports explicitly.
- S3 and DynamoDB gateway endpoints have no hourly endpoint charge and can avoid
  NAT processing for matching traffic.
- VPC Block Public Access is an account/Region singleton. Own it from one module
  instance and coordinate changes with the account networking owner.

> [!CAUTION]
> Adopting default VPC resources removes default-SG rules, default-NACL allow rules,
> non-local default routes, and route propagation. Inventory live dependencies first.

See [Security and operations](docs/security-and-operations.md) and
[`examples/secure_isolated`](examples/secure\_isolated) for ownership boundaries,
Flow Logs, DHCP, names, tags, and operational checks.

## Output stability

| Tier | Contract | Intended use |
|---|---|---|
| Tier 1 — stable handles | Output names, value shapes, and existing map keys are semver-protected. Minor releases may add outputs or map keys. | All new consumers. |
| Tier 2 — compatibility | Deprecated names and outer shapes remain during 5.x and are removed in 6.0. | Temporary migration of existing consumers. |
| Tier 3 — escape hatch | `resources` exposes provider-shaped internal collections with no semver guarantee. | Attributes not represented by Tier 1; isolate usage behind caller-owned outputs. |

See [Outputs and composition](docs/outputs.md) for patterns, compatibility details,
and null/empty collection conventions.

## Testing and contributing

The native Terraform suite covers positive plans, negative validation contracts,
migration state moves, and all twelve examples. Mock-provider tests require
Terraform `>= 1.7`.

```shell
terraform init -backend=false
terraform test -no-color
terraform fmt -check -recursive .
tflint --init
tflint --recursive
terraform validate -no-color
```

See [contributing.md](contributing.md) before submitting changes.

---

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.29 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.29 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_network_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_network_acl) | resource |
| [aws_default_route_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_route_table) | resource |
| [aws_default_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_ec2_transit_gateway_vpc_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |
| [aws_egress_only_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/egress_only_internet_gateway) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_network_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_network_acl_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_association) | resource |
| [aws_network_acl_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_networkmanager_attachment_accepter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_attachment_accepter) | resource |
| [aws_networkmanager_vpc_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_vpc_attachment) | resource |
| [aws_route.custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.cwan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.cwan_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.eigw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.igw_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.igw_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.nat64](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.tgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.tgw_attachment_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.tgw_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.top_level](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_block_public_access_exclusion.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_block_public_access_exclusion) | resource |
| [aws_vpc_block_public_access_options.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_block_public_access_options) | resource |
| [aws_vpc_dhcp_options.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options) | resource |
| [aws_vpc_dhcp_options_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options_association) | resource |
| [aws_vpc_endpoint.gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint_route_table_association.gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_route_table_association) | resource |
| [aws_vpc_ipv4_cidr_block_association.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipv4_cidr_block_association) | resource |
| [aws_vpc_ipv6_cidr_block_association.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipv6_cidr_block_association) | resource |
| [aws_vpclattice_service_network_vpc_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_service_network_vpc_association) | resource |
| [terraform_data.attachment_contract_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.availability_zone_count_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.cidr_pinning_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.cidrs_az_count_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.core_network_readiness](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.dns64_requires_nat_gateway](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.eigw_injection_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.eigw_requires_ipv6](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.gateway_endpoint_routing_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.igw_injection_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.injected_ipv6_association_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.injected_route_table_all_az_nat_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.injected_route_table_identity_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.ipv6_cidr_calculation_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.ipv6_cidrs_az_count_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.isolated_injected_route_table_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.nat_gateway_az_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.nat_gateway_eip_allocation_ids_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.nat_gateway_existing_ids_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.nat_gateway_subnet_group_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.nat_routing_requires_nat_gateway](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.route_table_routing_compatibility_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.subnet_existing_ids_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.subnet_ipv6_secondary_cidr_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.subnet_ipv6_vpc_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.subnet_secondary_cidr_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.top_level_routes_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.vpc_ipv4_addressing_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_availability_zones.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_network_acls.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/network_acls) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route_table.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_table) | data source |
| [aws_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) | data source |
| [aws_subnet.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [aws_vpc.managed_ipv6_associations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_addressing"></a> [addressing](#input\_addressing) | VPC addressing with one mandatory primary IPv4 block and zero or more<br/>caller-keyed secondary associations. Each secondary entry is a closed union:<br/>configure exactly one of `ipv4` or `ipv6`. The family sub-objects mirror the<br/>subnet contract, keep family-specific arguments impossible to mix, and make<br/>each map key durable Terraform resource identity.<br/><br/>The primary block supports static IPv4, IPv4 IPAM, or an empty object when an<br/>existing VPC supplies the primary CIDR. Secondary entries support create or<br/>inject mode. IPv6 is always secondary, may be Amazon-provided or allocated<br/>from IPAM, and supports VPC prefixes /44 through /60 in increments of /4.<br/>AWS service quotas, rather than this module, govern association cardinality. | <pre>object({<br/>    primary = object({<br/>      cidr_block     = optional(string)<br/>      ipam_pool_id   = optional(string)<br/>      netmask_length = optional(number)<br/>    })<br/>    secondary = optional(map(object({<br/>      ipv4 = optional(object({<br/>        create         = optional(bool, true)<br/>        association_id = optional(string)<br/>        cidr_block     = optional(string)<br/>        ipam_pool_id   = optional(string)<br/>        netmask_length = optional(number)<br/>      }))<br/>      ipv6 = optional(object({<br/>        create          = optional(bool, true)<br/>        association_id  = optional(string)<br/>        amazon_assigned = optional(bool, false)<br/>        cidr_block      = optional(string)<br/>        ipam_pool_id    = optional(string)<br/>        netmask_length  = optional(number)<br/>      }))<br/>    })), {})<br/>  })</pre> | n/a | yes |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | AZ selection. Provide either an explicit list of AZ names or a count<br/>(takes first N from the region alphabetically). Exactly one is required.<br/><br/>⚠️  `count` mode is for DEVELOPMENT ONLY. For production, always use explicit<br/>`names` to guarantee AZ stability. Because `count` resolves AZ names through an<br/>AWS data source, preconditions that depend on the resolved AZ set are unknown<br/>during the initial plan and are deferred by Terraform to apply time. | <pre>object({<br/>    names = optional(list(string))<br/>    count = optional(number)<br/>  })</pre> | n/a | yes |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC configuration. Set `create = false` and `id` to reference an existing VPC.<br/>The explicit boolean decides resource cardinality, so `id` may be computed by an<br/>upstream resource or module without making count/for\_each unknown.<br/><br/>Set `igw_create = false` and `igw_id` to inject an existing Internet Gateway.<br/>Set `eigw_create = false` and `eigw_id` to inject an existing egress-only<br/>Internet Gateway. Gateway resources are created only when resolved routing<br/>requires them. Gateway Name tags accept a complete format with `{vpc}`;<br/>gateway-specific tags override global tags while the generated Name wins last. | <pre>object({<br/>    name             = string<br/>    create           = optional(bool, true)<br/>    id               = optional(string)<br/>    igw_create       = optional(bool, true)<br/>    igw_id           = optional(string)<br/>    igw_name_format  = optional(string, "{vpc}-igw")<br/>    igw_tags         = optional(map(string), {})<br/>    eigw_create      = optional(bool, true)<br/>    eigw_id          = optional(string)<br/>    eigw_name_format = optional(string, "{vpc}-eigw")<br/>    eigw_tags        = optional(map(string), {})<br/>    instance_tenancy = optional(string, "default")<br/>    dns = optional(object({<br/>      enable_hostnames = optional(bool, true)<br/>      enable_support   = optional(bool, true)<br/>    }), {})<br/>    tags = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_calculated_subnet_az_capacity"></a> [calculated\_subnet\_az\_capacity](#input\_calculated\_subnet\_az\_capacity) | Number of AZ slots reserved per calculated subnet group. The default of<br/>three matches the most common regional layout (three AZs). Deployments in<br/>regions with more AZs may raise it up to six; the value must always cover<br/>every configured AZ. Changing it on an existing VPC renumbers calculated<br/>subnets, so established deployments must keep the value they were created<br/>with. | `number` | `3` | no |
| <a name="input_default_resources"></a> [default\_resources](#input\_default\_resources) | Opt-in management of the VPC's existing default resources. These resources<br/>are adopted, never created: enabling a selector takes ownership of the<br/>default security group, network ACL, or route table already created by AWS.<br/><br/>All selectors default false so v4 migrations and existing callers retain a<br/>zero-diff plan. Enabling security-group management removes all default SG<br/>ingress/egress rules. Enabling network-ACL management removes its default<br/>allow rules. Enabling route-table management removes non-local routes and<br/>gateway propagation. Review live workloads before adoption.<br/><br/>name\_format controls generated Name tags with {vpc} and {resource}; resource<br/>resolves to default-security-group, default-network-acl, or default-route-table. | <pre>object({<br/>    manage_security_group = optional(bool, false)<br/>    manage_network_acl    = optional(bool, false)<br/>    manage_route_table    = optional(bool, false)<br/>    name_format           = optional(string, "{vpc}-{resource}")<br/>    tags                  = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_dhcp_options"></a> [dhcp\_options](#input\_dhcp\_options) | DHCP option set for the VPC. Enable create mode from typed settings or inject an existing dhcp\_options\_id. | <pre>object({<br/>    enabled                           = optional(bool, false)<br/>    create                            = optional(bool, true)<br/>    id                                = optional(string)<br/>    domain_name                       = optional(string)<br/>    domain_name_servers               = optional(list(string), ["AmazonProvidedDNS"])<br/>    ntp_servers                       = optional(list(string), [])<br/>    netbios_name_servers              = optional(list(string), [])<br/>    netbios_node_type                 = optional(number)<br/>    ipv6_address_preferred_lease_time = optional(string)<br/>    tags                              = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_flow_logs"></a> [flow\_logs](#input\_flow\_logs) | VPC Flow Logs keyed by a stable logical name. Map keys are Terraform state<br/>identity and must not be renamed without a moved block.<br/><br/>destination\_type accepts cloudwatch, s3, or kinesis (Kinesis Data Firehose).<br/>CloudWatch supports create-or-inject for both the log group and the VPC Flow<br/>Logs IAM role. Set `create_destination=false` and/or `create_iam_role=false`<br/>when injecting computed ARNs. `name_format` controls the Flow Log `Name` tag<br/>with `{vpc}`/`{key}` placeholders. `cloudwatch_options.name_format` controls<br/>the log-group tag and inherits the parent format when null. Set either format<br/>to the empty string to omit `Name` even when caller tag maps contain it.<br/>`cloudwatch_options.name` is the fixed physical log-group name; set it to the<br/>exact imported v4 name during migration. `role_name_prefix` is<br/>passed through exactly (maximum 38 characters) so a moved v4 IAM role keeps its<br/>original prefix and is not replaced. S3 buckets and Firehose delivery streams<br/>are external resources: destination\_arn is required so their lifecycle, KMS,<br/>retention, and ownership policies remain outside this VPC module.<br/><br/>Migration note: use the exact v4 physical name with three root declarative<br/>`removed { destroy=false }` blocks (log group, managed policy, attachment)<br/>plus the log-group `import` handoff. Provider import records the observed name<br/>and a computed name\_prefix; omitting name\_prefix in v5 avoids drift. | <pre>map(object({<br/>    enabled                        = optional(bool, true)<br/>    create                         = optional(bool, true)<br/>    id                             = optional(string)<br/>    destination_type               = optional(string, "cloudwatch")<br/>    create_destination             = optional(bool, true)<br/>    destination_arn                = optional(string)<br/>    create_iam_role                = optional(bool, true)<br/>    iam_role_arn                   = optional(string)<br/>    deliver_cross_account_role_arn = optional(string)<br/>    traffic_type                   = optional(string, "ALL")<br/>    log_format                     = optional(string)<br/>    max_aggregation_interval       = optional(number, 600)<br/>    name_format                    = optional(string, "{vpc}-{key}-flow-logs")<br/>    role_name_prefix               = optional(string)<br/>    role_permissions_boundary      = optional(string)<br/>    cloudwatch_options = optional(object({<br/>      name              = optional(string)<br/>      name_format       = optional(string)<br/>      retention_in_days = optional(number, 30)<br/>      kms_key_id        = optional(string)<br/>    }), {})<br/>    s3_options = optional(object({<br/>      file_format                = optional(string, "plain-text")<br/>      hive_compatible_partitions = optional(bool, false)<br/>      per_hour_partition         = optional(bool, false)<br/>    }), {})<br/>    tags = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_gateway_endpoints"></a> [gateway\_endpoints](#input\_gateway\_endpoints) | Gateway VPC endpoints keyed by a stable caller-owned identifier. Each entry<br/>explicitly selects service `s3` or `dynamodb`; at most one endpoint per<br/>service is allowed. Conventional keys are `s3` and `dynamodb`.<br/><br/>Create mode owns one aws\_vpc\_endpoint and accepts an optional JSON policy.<br/>Inject mode uses create=false plus endpoint\_id and never owns endpoint policy.<br/>Route-table associations are declared co-locally under subnet-group routing.<br/>name\_format accepts {vpc}, {service}, and {key}. | <pre>map(object({<br/>    service     = string<br/>    create      = optional(bool, true)<br/>    endpoint_id = optional(string)<br/>    policy      = optional(string)<br/>    name_format = optional(string, "{vpc}-{service}-gateway-endpoint")<br/>    tags        = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_nat_gateway"></a> [nat\_gateway](#input\_nat\_gateway) | NAT Gateway configuration. `single_az` and `all_azs` create zonal Gateways;<br/>`regional` creates one public VPC-level Gateway and repeats its ID by configured<br/>AZ in Tier 1 outputs so existing route-key shapes remain stable. The `az` field<br/>is required only for `single_az`. Regional mode rejects both `az` and<br/>`subnet_group`, does not require public subnets, and does not support private NAT.<br/><br/>Set `create = false` plus `existing_ids` to inject existing NAT Gateways.<br/>Zonal maps are keyed by selected AZ; regional injection uses exactly the key<br/>`regional`. The explicit boolean keeps cardinality plan-known when IDs are computed.<br/><br/>`connectivity_type` controls public (internet-facing) versus private<br/>(inter-VPC) zonal NAT. Regional NAT is always public.<br/><br/>`subnet_group` explicitly selects the group that hosts zonal NAT Gateways.<br/>It must reference a public group for public NAT or a private group for private<br/>NAT. Null selects the first compatible group alphabetically. Regional mode is<br/>VPC-level and therefore requires `subnet_group = null`.<br/><br/>EIP `create` uses ordinary module-owned EIPs for zonal mode and AWS automatic<br/>IP/AZ management for regional mode. Regional `byoip_pool` and `existing` use<br/>manual `availability_zone_address` blocks for every configured AZ; BYOIP creates<br/>one module-owned EIP per AZ, while existing keeps EIP lifecycle caller-owned.<br/><br/>`name_format` controls the complete NAT Gateway Name tag. The EIP inherits it<br/>unless `eip.name_format` is set. Both accept `{vpc}`, `{group}`, and `{az}`;<br/>regional resource naming resolves both `{group}` and `{az}` to `regional`.<br/>Zonal NAT/EIP tags inherit host-group tags; regional resources use global plus<br/>NAT/EIP-specific tags because no host subnet group exists. | <pre>object({<br/>    mode              = optional(string, "none")<br/>    create            = optional(bool, true)<br/>    az                = optional(string)<br/>    connectivity_type = optional(string, "public") # "public" | "private"<br/>    subnet_group      = optional(string)           # explicit NAT host group; null = first compatible group<br/>    existing_ids      = optional(map(string))      # zonal: az → ID; regional: { regional = ID }<br/>    name_format       = optional(string, "{vpc}-nat-{az}")<br/>    tags              = optional(map(string), {})<br/>    eip = optional(object({<br/>      mode             = optional(string, "create")<br/>      public_ipv4_pool = optional(string)<br/>      allocation_ids   = optional(map(string)) # null unless existing EIPs are selected<br/>      name_format      = optional(string)<br/>      tags             = optional(map(string), {})<br/>    }), { mode = "create" })<br/>  })</pre> | <pre>{<br/>  "mode": "none"<br/>}</pre> | no |
| <a name="input_routes"></a> [routes](#input\_routes) | Caller-keyed routes applied to every route table in `from_group`. Use this<br/>late-bound surface when a target is produced by a module that consumes this<br/>VPC's subnet outputs. Module-managed tables use state keys<br/>`<route-key>/<az>`. An injected table is one shared physical table and uses<br/>`<route-key>/shared`; it accepts only `target.id`. Route keys must not contain<br/>`/`.<br/><br/>`target.id` replicates one target to every module-managed AZ or creates one<br/>route on an injected shared table. `target.ids_by_az` selects the target<br/>matching each configured AZ and therefore requires module-managed per-AZ route<br/>tables. Exactly one of `id` and `ids_by_az` must be set. A `prefix_list`<br/>destination on a table with an S3 or DynamoDB gateway endpoint is rejected<br/>unless `acknowledge_gateway_endpoint_coexistence=true`, because the endpoint's<br/>service-managed prefix-list ID cannot be compared during planning.<br/><br/>AWS requires routes toward a VPC endpoint that are more specific than the local<br/>route to exactly match a subnet CIDR block. The module applies this middlebox<br/>constraint to `vpc_endpoint` and `network_interface` targets when a destination<br/>overlaps a plan-known IPv4 CIDR of a module-managed VPC and subnet. CIDRs of an<br/>injected VPC, injected subnets, and IPAM-derived subnets cannot be checked at<br/>plan time; AWS enforces the constraint when the route is created. Destination<br/>and target types use the same closed unions as `subnets[*].routes`. | <pre>map(object({<br/>    from_group                               = string<br/>    acknowledge_gateway_endpoint_coexistence = optional(bool, false)<br/>    destination = object({<br/>      type  = string<br/>      value = string<br/>    })<br/>    target = object({<br/>      type      = string<br/>      id        = optional(string)<br/>      ids_by_az = optional(map(string))<br/>    })<br/>  }))</pre> | `{}` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Map of subnet groups. Each key is a stable logical name (used in state keys<br/>as "key/az"). Keys are IMMUTABLE post-deploy — renaming requires `moved` blocks.<br/><br/>The `role` field determines creation behavior:<br/>  - public:          gets IGW route, optional NAT gateway hosting<br/>  - private:         standard private subnet, optional NAT/EIGW routing<br/>  - isolated:        no Internet/transit routing; S3/DynamoDB gateway endpoints allowed<br/>  - transit\_gateway: dedicated small subnets for TGW ENIs<br/>  - core\_network:    dedicated small subnets for Cloud WAN attachments<br/><br/>Multiple subnet groups per role are allowed:<br/>  - public: N groups allowed (e.g. DMZ, edge, GWLB)<br/>  - transit\_gateway: N groups allowed; each plural attachment selects one group,<br/>    and several attachments may intentionally reuse the same attachment subnets<br/>  - core\_network: limited to 1 group (Cloud WAN attachment adapter is singular)<br/><br/>Set `manage_route_table = false` plus `route_table_key` and `route_table_id`<br/>to inject an existing route table. `route_table_key` is caller-owned, immutable<br/>Terraform state identity; renaming it changes every `injected/<key>/...` route<br/>and gateway-endpoint association address and requires root-module `moved` blocks.<br/>Changing `manage_route_table` after deployment is an ownership handoff, not an<br/>in-place toggle: `true` to `false` removes the managed tables and re-keys<br/>top-level routes from `<route-key>/<az>` to `<route-key>/shared`. Preserve tables<br/>with root-module `removed` blocks using `destroy = false`, and stage the route<br/>cutover when an interruption is unacceptable.<br/>Groups sharing one physical table must use the same key and ID. The module<br/>associates every subnet while materializing each route and gateway-endpoint<br/>association only once per physical key. For role = "isolated", an injected<br/>route table is rejected by default because the AWS provider omits propagated<br/>and service-managed route classes from its route-table data source; the module<br/>cannot prove that an unmanaged table is isolated. The dangerous<br/>isolated\_accepts\_uninspected\_route\_table opt-in is the only supported path and<br/>transfers responsibility for every existing and future route to the caller.<br/>A shared injected table cannot provide per-AZ NAT targets,<br/>so `nat_gateway.mode = "all_azs"` is rejected when any referencing group<br/>requests NAT/NAT64.<br/><br/>`name_format` controls the complete subnet Name tag with `{vpc}`, `{group}`,<br/>and `{az}` placeholders. `{group}` resolves `name_prefix` or the map key.<br/>`route_table_name_format` can diverge; when omitted it inherits `name_format`.<br/><br/>`public_options.map_public_ip` is opt-in and defaults to false, matching v4:<br/>a public route table does not imply automatic public IPv4 assignment to ENIs.<br/><br/>`network_acl` is optional. When absent, the module creates no NACL resources or<br/>associations and AWS default-NACL behavior is retained. Create mode owns one ACL<br/>per group; inject mode uses an existing ID while still managing declared rules<br/>and every subnet association. Ingress/egress maps are keyed by explicit AWS rule<br/>number so source declaration order never becomes state identity. | <pre>map(object({<br/>    role         = string<br/>    create       = optional(bool, true)<br/>    existing_ids = optional(map(string))<br/><br/>    # ── IPv4 Addressing (one of netmask/cidrs_by_az/ipam required unless ipv6 native_only) ──<br/>    ipv4 = optional(object({<br/>      netmask        = optional(number)<br/>      cidrs_by_az    = optional(map(string))<br/>      ipam_pool_id   = optional(string)<br/>      netmask_length = optional(number)<br/>      # Absolute CIDR group slot for pinning. Each slot reserves<br/>      # `calculated_subnet_az_capacity` AZ-sized CIDRs (default 3) at this netmask.<br/>      # Pinned ranges never move when groups or AZs<br/>      # are added/removed; overlapping pins across netmasks are rejected.<br/>      cidr_index         = optional(number)<br/>      secondary_cidr_key = optional(string)<br/>    }))<br/><br/>    # ── IPv6 Addressing ──<br/>    ipv6 = optional(object({<br/>      secondary_cidr_key = optional(string)<br/>      auto_assign        = optional(bool, false)<br/>      cidrs_by_az        = optional(map(string))<br/>      ipam_pool_id       = optional(string)<br/>      netmask_length     = optional(number)<br/>      native_only        = optional(bool, false)<br/>      cidr_index         = optional(number)<br/>    }))<br/><br/>    # ── Naming, Tags, and Route Table Injection ──<br/>    name_prefix                              = optional(string)<br/>    name_format                              = optional(string)<br/>    route_table_name_format                  = optional(string)<br/>    tags                                     = optional(map(string), {})<br/>    manage_route_table                       = optional(bool, true)<br/>    route_table_key                          = optional(string) # stable physical identity when injecting<br/>    route_table_id                           = optional(string) # effective ID when injecting<br/>    isolated_accepts_uninspected_route_table = optional(bool, false)<br/><br/>    # ── Optional stateless Network ACL (one per subnet group) ──<br/>    # Rule map keys are the explicit AWS rule numbers and therefore stable state<br/>    # identity, independent of declaration order.<br/>    network_acl = optional(object({<br/>      create      = optional(bool, true)<br/>      id          = optional(string)<br/>      name_format = optional(string, "{vpc}-{group}-nacl")<br/>      tags        = optional(map(string), {})<br/>      ingress = optional(map(object({<br/>        protocol        = string<br/>        action          = string<br/>        cidr_block      = optional(string)<br/>        ipv6_cidr_block = optional(string)<br/>        from_port       = optional(number)<br/>        to_port         = optional(number)<br/>        icmp_type       = optional(number)<br/>        icmp_code       = optional(number)<br/>      })), {})<br/>      egress = optional(map(object({<br/>        protocol        = string<br/>        action          = string<br/>        cidr_block      = optional(string)<br/>        ipv6_cidr_block = optional(string)<br/>        from_port       = optional(number)<br/>        to_port         = optional(number)<br/>        icmp_type       = optional(number)<br/>        icmp_code       = optional(number)<br/>      })), {})<br/>    }))<br/><br/>    # ── Routing (co-located per subnet group) ──<br/>    # transit_gateway and core_network accept lists of destinations<br/>    # to support multiple routes (e.g. 10.0.0.0/8 + 172.16.0.0/12 → TGW).<br/>    # internet_gateway defaults to null; auto-resolved as true for<br/>    # role="public", false otherwise. Set explicitly to override.<br/>    routing = optional(object({<br/>      nat_gateway                      = optional(bool, false)<br/>      egress_only_igw                  = optional(bool, false)<br/>      internet_gateway                 = optional(bool)                  # null = auto (true for public, false otherwise)<br/>      dns64                            = optional(bool, false)           # Also creates 64:ff9b::/96 -> NAT GW; requires NAT<br/>      transit_gateway                  = optional(list(string))          # DEPRECATED singular adapter<br/>      transit_gateway_ipv6             = optional(list(string))          # DEPRECATED singular adapter<br/>      transit_gateway_attachments      = optional(map(list(string)), {}) # attachment key => IPv4 CIDR/prefix-list destinations<br/>      transit_gateway_attachments_ipv6 = optional(map(list(string)), {}) # attachment key => IPv6 CIDR/prefix-list destinations<br/>      core_network                     = optional(list(string))          # list of CIDRs/prefix-list IDs to route via CWAN<br/>      core_network_ipv6                = optional(list(string))          # list of IPv6 CIDRs/prefix-list IDs<br/>      s3_gateway_endpoint              = optional(bool, false)<br/>      dynamodb_gateway_endpoint        = optional(bool, false)<br/>    }), {})<br/><br/>    # Caller-owned route keys are Terraform state identity; destination and<br/>    # target IDs remain values and may therefore be computed during plan.<br/>    routes = optional(map(object({<br/>      destination = object({<br/>        type  = string # ipv4_cidr | ipv6_cidr | prefix_list<br/>        value = string<br/>      })<br/>      target = object({<br/>        type = string # vpc_peering | vpc_endpoint | network_interface | virtual_private_gateway | local_gateway | carrier_gateway<br/>        id   = string<br/>      })<br/>    })), {})<br/><br/>    # ── Public role options ──<br/>    public_options = optional(object({<br/>      map_public_ip = optional(bool, false)<br/>    }))<br/><br/>    # ── Transit Gateway attachment options ──<br/>    transit_gateway_options = optional(object({<br/>      id                              = string<br/>      create                          = optional(bool, true)<br/>      attachment_id                   = optional(string)<br/>      default_route_table_association = optional(bool, true)<br/>      default_route_table_propagation = optional(bool, true)<br/>      appliance_mode_support          = optional(bool, false)<br/>      dns_support                     = optional(bool, true)<br/>      security_group_referencing      = optional(bool, true) # Requires provider >= 5.69<br/>    }))<br/><br/>    # ── Core Network (Cloud WAN) attachment options ──<br/>    core_network_options = optional(object({<br/>      id                 = string<br/>      arn                = optional(string) # Optional: auto-derived from id if omitted<br/>      create             = optional(bool, true)<br/>      attachment_id      = optional(string)<br/>      appliance_mode     = optional(bool, false)<br/>      require_acceptance = optional(bool, false)<br/>      accept_attachment  = optional(bool, false)<br/>      create_accepter    = optional(bool, true)<br/>      accepter_id        = optional(string)<br/>      # null defers to the AWS service defaults so existing attachments see no diff<br/>      dns_support                = optional(bool)<br/>      security_group_referencing = optional(bool)<br/>      routing_policy_label       = optional(string)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources created by this module. | `map(string)` | `{}` | no |
| <a name="input_transit_gateway_attachments"></a> [transit\_gateway\_attachments](#input\_transit\_gateway\_attachments) | Transit Gateway VPC attachments keyed by caller-owned state identity. AWS<br/>permits up to five distinct Transit Gateways per VPC, while still allowing<br/>only one attachment from a given VPC to the same Transit Gateway. Each entry<br/>selects a transit\_gateway subnet group and independently supports create or<br/>inject. Route maps under subnets[*].routing reference these attachment keys.<br/><br/>The legacy singular subnets[*].transit\_gateway\_options shape remains as a<br/>deprecated adapter, may appear on at most one subnet group, and must not be<br/>combined with this plural map. Use this top-level map for multiple attachments. | <pre>map(object({<br/>    subnet_group                    = string<br/>    id                              = string<br/>    create                          = optional(bool, true)<br/>    attachment_id                   = optional(string)<br/>    default_route_table_association = optional(bool, true)<br/>    default_route_table_propagation = optional(bool, true)<br/>    appliance_mode_support          = optional(bool, false)<br/>    dns_support                     = optional(bool, true)<br/>    security_group_referencing      = optional(bool, true)<br/>    tags                            = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_vpc_block_public_access"></a> [vpc\_block\_public\_access](#input\_vpc\_block\_public\_access) | Regional VPC Block Public Access options. This is an account/Region singleton;<br/>enable it from exactly one module instance. create=false injects existing<br/>options by ID. Exclusions are keyed by stable names and independently support<br/>create-or-inject. A created exclusion targets this VPC or one subnet. | <pre>object({<br/>    enabled                     = optional(bool, false)<br/>    create                      = optional(bool, true)<br/>    id                          = optional(string)<br/>    internet_gateway_block_mode = optional(string, "block-ingress")<br/>    exclusions = optional(map(object({<br/>      create                          = optional(bool, true)<br/>      id                              = optional(string)<br/>      internet_gateway_exclusion_mode = optional(string, "allow-bidirectional")<br/>      target                          = optional(string, "vpc")<br/>      subnet_key                      = optional(string)<br/>      subnet_id                       = optional(string)<br/>      tags                            = optional(map(string), {})<br/>    })), {})<br/>  })</pre> | `{}` | no |
| <a name="input_vpc_lattice"></a> [vpc\_lattice](#input\_vpc\_lattice) | VPC Lattice association. enabled is the plan-known cardinality selector; identifiers may be computed. When private DNS is enabled, dns\_options defaults to AWS's VERIFIED\_DOMAINS\_ONLY behavior. | <pre>object({<br/>    enabled                    = optional(bool, false)<br/>    create                     = optional(bool, true)<br/>    id                         = optional(string)<br/>    service_network_identifier = optional(string)<br/>    security_group_ids         = optional(set(string), [])<br/>    private_dns_enabled        = optional(bool, false)<br/>    dns_options = optional(object({<br/>      private_dns_preference        = optional(string, "VERIFIED_DOMAINS_ONLY")<br/>      private_dns_specified_domains = optional(set(string))<br/>    }), {})<br/>    tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_azs"></a> [azs](#output\_azs) | List of Availability Zones where subnets were created. |
| <a name="output_core_network_attachment"></a> [core\_network\_attachment](#output\_core\_network\_attachment) | DEPRECATED: v4-compatible full Cloud WAN attachment object. Use core\_network\_attachment\_id. Removed in v6. |
| <a name="output_core_network_attachment_accepter_id"></a> [core\_network\_attachment\_accepter\_id](#output\_core\_network\_attachment\_accepter\_id) | Cloud WAN attachment accepter ID (created or injected), or null when acceptance is not managed. |
| <a name="output_core_network_attachment_id"></a> [core\_network\_attachment\_id](#output\_core\_network\_attachment\_id) | Cloud WAN Core Network VPC attachment ID, or null when the role is absent. |
| <a name="output_core_network_subnet_attributes_by_az"></a> [core\_network\_subnet\_attributes\_by\_az](#output\_core\_network\_subnet\_attributes\_by\_az) | DEPRECATED: v4-compatible map of full Cloud WAN subnet objects keyed by AZ. Use Tier 1 subnet outputs. Removed in v6. |
| <a name="output_default_network_acl_id"></a> [default\_network\_acl\_id](#output\_default\_network\_acl\_id) | ID of the AWS-created default network ACL for this VPC, whether or not default\_resources manages it. |
| <a name="output_default_resource_ids"></a> [default\_resource\_ids](#output\_default\_resource\_ids) | IDs of the VPC's default security group, network ACL, and route table; always populated, while default\_resources controls only lifecycle adoption. |
| <a name="output_default_route_table_id"></a> [default\_route\_table\_id](#output\_default\_route\_table\_id) | ID of the AWS-created default route table for a created VPC, or the resolved main/default route table for an injected VPC; always available independently of default\_resources management. |
| <a name="output_default_security_group_id"></a> [default\_security\_group\_id](#output\_default\_security\_group\_id) | ID of the AWS-created default security group for this VPC, whether or not default\_resources manages it. |
| <a name="output_dhcp_options_id"></a> [dhcp\_options\_id](#output\_dhcp\_options\_id) | DHCP option set ID associated with the VPC (created or injected), or null when disabled. |
| <a name="output_egress_only_igw_id"></a> [egress\_only\_igw\_id](#output\_egress\_only\_igw\_id) | Egress-only Internet Gateway ID (created or injected), or null when unused. |
| <a name="output_egress_only_internet_gateway"></a> [egress\_only\_internet\_gateway](#output\_egress\_only\_internet\_gateway) | DEPRECATED: v4-compatible full Egress-only Internet Gateway object. Use egress\_only\_igw\_id. Removed in v6. |
| <a name="output_flow_log_attributes"></a> [flow\_log\_attributes](#output\_flow\_log\_attributes) | DEPRECATED: v4-compatible single full Flow Log object. Uses key 'default', or the only configured Flow Log. Use flow\_log\_ids. Removed in v6. |
| <a name="output_flow_log_destination_arns"></a> [flow\_log\_destination\_arns](#output\_flow\_log\_destination\_arns) | VPC Flow Log destination ARNs by stable flow\_logs map key. |
| <a name="output_flow_log_ids"></a> [flow\_log\_ids](#output\_flow\_log\_ids) | VPC Flow Log IDs by the stable flow\_logs map key. Shape: map(key, flow\_log\_id). |
| <a name="output_flow_log_role_arns"></a> [flow\_log\_role\_arns](#output\_flow\_log\_role\_arns) | CloudWatch delivery role ARNs by flow-log key; null for S3 and Firehose. |
| <a name="output_gateway_endpoint_ids"></a> [gateway\_endpoint\_ids](#output\_gateway\_endpoint\_ids) | Gateway VPC endpoint IDs by stable caller-owned gateway\_endpoints key. |
| <a name="output_gateway_endpoint_route_table_association_ids"></a> [gateway\_endpoint\_route\_table\_association\_ids](#output\_gateway\_endpoint\_route\_table\_association\_ids) | Gateway endpoint route-table association IDs keyed '<group>/<az-or-injected>/gateway-endpoint/<service>'. |
| <a name="output_internet_gateway"></a> [internet\_gateway](#output\_internet\_gateway) | DEPRECATED: v4-compatible full created Internet Gateway object. Use internet\_gateway\_id. Removed in v6. |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | Internet Gateway ID (created or injected), or null when no IGW is needed. |
| <a name="output_main_route_table_id"></a> [main\_route\_table\_id](#output\_main\_route\_table\_id) | ID of the VPC's current main route table, which can differ from the originally AWS-created default route table. |
| <a name="output_nat_eip_allocation_ids"></a> [nat\_eip\_allocation\_ids](#output\_nat\_eip\_allocation\_ids) | Effective public NAT EIP allocation IDs. Zonal keys are AZs; regional keys are '<az>/<allocation-id>'. Empty for injected/private NAT. |
| <a name="output_nat_gateway_attributes_by_az"></a> [nat\_gateway\_attributes\_by\_az](#output\_nat\_gateway\_attributes\_by\_az) | DEPRECATED: v4-compatible map of full created NAT objects keyed by AZ; Regional NAT repeats one object per configured AZ. Use Tier 1 outputs. Removed in v6. |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | NAT Gateway IDs by configured AZ. Regional mode repeats its one VPC-level ID for every AZ; none returns an empty map. Shape: map(az, nat\_gateway\_id). |
| <a name="output_nat_private_ips"></a> [nat\_private\_ips](#output\_nat\_private\_ips) | Created zonal NAT private IPs by AZ. Regional provider addresses expose no private IP; injected NAT returns an empty map. |
| <a name="output_nat_public_ips"></a> [nat\_public\_ips](#output\_nat\_public\_ips) | Created public NAT IPs. Zonal keys are AZs; regional keys are '<az>/<allocation-id>' so every scaled address is preserved. Empty for injected/private NAT. |
| <a name="output_natgw_id_per_az"></a> [natgw\_id\_per\_az](#output\_natgw\_id\_per\_az) | DEPRECATED: v4-compatible map(az, object({id=string})); single\_az and regional repeat one selected ID. Use nat\_gateway\_ids. Removed in v6. |
| <a name="output_network_acl_association_ids"></a> [network\_acl\_association\_ids](#output\_network\_acl\_association\_ids) | Managed Network ACL association IDs keyed by stable '<group>/<az>' subnet identity. |
| <a name="output_network_acl_ids_by_group"></a> [network\_acl\_ids\_by\_group](#output\_network\_acl\_ids\_by\_group) | Created or injected Network ACL IDs by stable subnet-group key; groups without network\_acl are absent. |
| <a name="output_network_acl_rule_ids"></a> [network\_acl\_rule\_ids](#output\_network\_acl\_rule\_ids) | Managed Network ACL rule IDs keyed '<group>/<ingress\|egress>/<rule-number>'. |
| <a name="output_private_subnet_attributes_by_az"></a> [private\_subnet\_attributes\_by\_az](#output\_private\_subnet\_attributes\_by\_az) | DEPRECATED: v4-compatible map of full private subnet objects keyed '<group>/<az>'. Use Tier 1 subnet outputs. Removed in v6. |
| <a name="output_public_subnet_attributes_by_az"></a> [public\_subnet\_attributes\_by\_az](#output\_public\_subnet\_attributes\_by\_az) | DEPRECATED: v4-compatible map of full public subnet objects keyed by AZ. Use Tier 1 subnet outputs. Removed in v6. |
| <a name="output_regional_nat_gateway_addresses_by_az"></a> [regional\_nat\_gateway\_addresses\_by\_az](#output\_regional\_nat\_gateway\_addresses\_by\_az) | Created Regional NAT Gateway address records grouped by configured AZ; empty for zonal or injected NAT. |
| <a name="output_regional_nat_gateway_route_table_id"></a> [regional\_nat\_gateway\_route\_table\_id](#output\_regional\_nat\_gateway\_route\_table\_id) | AWS-managed route table ID for a created Regional NAT Gateway, or null for zonal/injected NAT. |
| <a name="output_resources"></a> [resources](#output\_resources) | UNSTABLE: internal resource collections for advanced composition. Provider objects are complete except flow\_log\_roles (arn/id/name/unique\_id only). Shape may change in any release; prefer Tier 1. |
| <a name="output_route_table_ids_by_group"></a> [route\_table\_ids\_by\_group](#output\_route\_table\_ids\_by\_group) | Route table IDs by subnet group. Shape: map(group\_name, list(route\_table\_id)). |
| <a name="output_route_table_ids_by_group_by_az"></a> [route\_table\_ids\_by\_group\_by\_az](#output\_route\_table\_ids\_by\_group\_by\_az) | Route table IDs by subnet group and AZ. Shape: map(group\_name, map(az, route\_table\_id)). |
| <a name="output_route_table_ids_by_semantic_role"></a> [route\_table\_ids\_by\_semantic\_role](#output\_route\_table\_ids\_by\_semantic\_role) | Route table IDs by semantic role. Shape: map(role, list(route\_table\_id)). |
| <a name="output_route_table_ids_by_semantic_role_by_az"></a> [route\_table\_ids\_by\_semantic\_role\_by\_az](#output\_route\_table\_ids\_by\_semantic\_role\_by\_az) | Route table IDs by semantic role and AZ. Shape: map(role, map(az, list(route\_table\_id))). |
| <a name="output_rt_attributes_by_type_by_az"></a> [rt\_attributes\_by\_type\_by\_az](#output\_rt\_attributes\_by\_type\_by\_az) | DEPRECATED: v4-compatible full route-table objects keyed type then AZ or '<group>/<az>' for private. Use Tier 1 route table IDs. Removed in v6. |
| <a name="output_secondary_cidr_association_ids"></a> [secondary\_cidr\_association\_ids](#output\_secondary\_cidr\_association\_ids) | Secondary IPv4 and IPv6 CIDR association IDs by stable caller-owned key. |
| <a name="output_secondary_ipv4_cidr_association_ids"></a> [secondary\_ipv4\_cidr\_association\_ids](#output\_secondary\_ipv4\_cidr\_association\_ids) | Secondary IPv4 CIDR association IDs by stable caller-owned key. |
| <a name="output_secondary_ipv6_cidr_association_ids"></a> [secondary\_ipv6\_cidr\_association\_ids](#output\_secondary\_ipv6\_cidr\_association\_ids) | Secondary IPv6 CIDR association IDs by stable caller-owned key. |
| <a name="output_subnet_arns_by_group_by_az"></a> [subnet\_arns\_by\_group\_by\_az](#output\_subnet\_arns\_by\_group\_by\_az) | Subnet ARNs by group and AZ. Shape: map(group\_name, map(az, arn)). |
| <a name="output_subnet_cidrs_by_group"></a> [subnet\_cidrs\_by\_group](#output\_subnet\_cidrs\_by\_group) | Subnet IPv4 CIDRs by group. Shape: map(group\_name, list(cidr\|null)). |
| <a name="output_subnet_cidrs_by_group_by_az"></a> [subnet\_cidrs\_by\_group\_by\_az](#output\_subnet\_cidrs\_by\_group\_by\_az) | Subnet IPv4 CIDRs by group and AZ. Shape: map(group\_name, map(az, cidr\|null)). |
| <a name="output_subnet_cidrs_by_role_by_az"></a> [subnet\_cidrs\_by\_role\_by\_az](#output\_subnet\_cidrs\_by\_role\_by\_az) | DEPRECATED: compatibility alias keyed by group name. Use subnet\_cidrs\_by\_group\_by\_az. Removed in v6. |
| <a name="output_subnet_cidrs_by_semantic_role"></a> [subnet\_cidrs\_by\_semantic\_role](#output\_subnet\_cidrs\_by\_semantic\_role) | Subnet IPv4 CIDRs by semantic role. Shape: map(role, list(cidr\|null)). |
| <a name="output_subnet_cidrs_by_semantic_role_by_az"></a> [subnet\_cidrs\_by\_semantic\_role\_by\_az](#output\_subnet\_cidrs\_by\_semantic\_role\_by\_az) | Subnet IPv4 CIDRs by semantic role and AZ. Shape: map(role, map(az, list(cidr\|null))). |
| <a name="output_subnet_connectivity_by_group_by_az"></a> [subnet\_connectivity\_by\_group\_by\_az](#output\_subnet\_connectivity\_by\_group\_by\_az) | Effective route capabilities by subnet group and AZ. Role and connectivity are independent axes. nat includes IPv4 NAT and DNS64/NAT64; internet is true for IGW, NAT/NAT64, or EIGW. |
| <a name="output_subnet_ids_by_group"></a> [subnet\_ids\_by\_group](#output\_subnet\_ids\_by\_group) | Subnet IDs by group. Shape: map(group\_name, list(subnet\_id)). |
| <a name="output_subnet_ids_by_group_by_az"></a> [subnet\_ids\_by\_group\_by\_az](#output\_subnet\_ids\_by\_group\_by\_az) | Subnet IDs by group and AZ. Shape: map(group\_name, map(az, subnet\_id)). |
| <a name="output_subnet_ids_by_role"></a> [subnet\_ids\_by\_role](#output\_subnet\_ids\_by\_role) | DEPRECATED: compatibility alias keyed by group name. Use subnet\_ids\_by\_group. Removed in v6. |
| <a name="output_subnet_ids_by_role_by_az"></a> [subnet\_ids\_by\_role\_by\_az](#output\_subnet\_ids\_by\_role\_by\_az) | DEPRECATED: compatibility alias keyed by group name. Use subnet\_ids\_by\_group\_by\_az. Removed in v6. |
| <a name="output_subnet_ids_by_semantic_role"></a> [subnet\_ids\_by\_semantic\_role](#output\_subnet\_ids\_by\_semantic\_role) | Subnet IDs by semantic role. Shape: map(role, list(subnet\_id)). |
| <a name="output_subnet_ids_by_semantic_role_by_az"></a> [subnet\_ids\_by\_semantic\_role\_by\_az](#output\_subnet\_ids\_by\_semantic\_role\_by\_az) | Subnet IDs by semantic role and AZ. Shape: map(role, map(az, list(subnet\_id))). |
| <a name="output_subnet_ids_with_nat_by_az"></a> [subnet\_ids\_with\_nat\_by\_az](#output\_subnet\_ids\_with\_nat\_by\_az) | Subnet IDs with an IPv4 NAT or DNS64/NAT64 route, grouped by AZ. Shape: map(az, list(subnet\_id)). |
| <a name="output_subnet_ids_without_internet_by_az"></a> [subnet\_ids\_without\_internet\_by\_az](#output\_subnet\_ids\_without\_internet\_by\_az) | Subnet IDs with no direct IGW, NAT/NAT64, or EIGW route, grouped by AZ. Transit and gateway-endpoint routes do not count as Internet access. Shape: map(az, list(subnet\_id)). |
| <a name="output_subnet_ipv6_cidrs_by_group_by_az"></a> [subnet\_ipv6\_cidrs\_by\_group\_by\_az](#output\_subnet\_ipv6\_cidrs\_by\_group\_by\_az) | Subnet IPv6 CIDRs by group and AZ. Shape: map(group\_name, map(az, cidr\|null)); the value is null when a subnet has no IPv6 association. |
| <a name="output_tgw_subnet_attributes_by_az"></a> [tgw\_subnet\_attributes\_by\_az](#output\_tgw\_subnet\_attributes\_by\_az) | DEPRECATED: v4-compatible map of full TGW subnet objects keyed by AZ. Use Tier 1 subnet outputs. Removed in v6. |
| <a name="output_transit_gateway_attachment_id"></a> [transit\_gateway\_attachment\_id](#output\_transit\_gateway\_attachment\_id) | DEPRECATED: scalar adapter for one Transit Gateway VPC attachment, or null when absent. Use transit\_gateway\_attachment\_ids. |
| <a name="output_transit_gateway_attachment_ids"></a> [transit\_gateway\_attachment\_ids](#output\_transit\_gateway\_attachment\_ids) | Transit Gateway VPC attachment IDs by caller-owned attachment key. The deprecated singular adapter uses key 'vpc'. Shape: map(attachment\_key, attachment\_id). |
| <a name="output_vpc_arn"></a> [vpc\_arn](#output\_vpc\_arn) | The ARN of the VPC (created or referenced). |
| <a name="output_vpc_attributes"></a> [vpc\_attributes](#output\_vpc\_attributes) | DEPRECATED: v4-compatible full VPC object. Use vpc\_id/vpc\_arn/vpc\_cidr\_block. Removed in v6. |
| <a name="output_vpc_block_public_access_exclusion_ids"></a> [vpc\_block\_public\_access\_exclusion\_ids](#output\_vpc\_block\_public\_access\_exclusion\_ids) | VPC Block Public Access exclusion IDs by stable key. |
| <a name="output_vpc_block_public_access_options_id"></a> [vpc\_block\_public\_access\_options\_id](#output\_vpc\_block\_public\_access\_options\_id) | VPC Block Public Access regional options ID (created or injected), or null when disabled. |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | The primary IPv4 CIDR block of the VPC. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC (created or referenced). |
| <a name="output_vpc_ipv4_cidr_blocks"></a> [vpc\_ipv4\_cidr\_blocks](#output\_vpc\_ipv4\_cidr\_blocks) | IPv4 VPC CIDR blocks by stable addressing key. The primary key is always present; secondary keys match IPv4 addressing.secondary entries. Shape: map(string\|null). |
| <a name="output_vpc_ipv6_cidr_block"></a> [vpc\_ipv6\_cidr\_block](#output\_vpc\_ipv6\_cidr\_block) | DEPRECATED singular adapter: the IPv6 CIDR under the first sorted secondary key, or null. Use vpc\_ipv6\_cidr\_blocks. |
| <a name="output_vpc_ipv6_cidr_blocks"></a> [vpc\_ipv6\_cidr\_blocks](#output\_vpc\_ipv6\_cidr\_blocks) | IPv6 VPC CIDR blocks by stable addressing.secondary key. |
| <a name="output_vpc_lattice_service_network_association"></a> [vpc\_lattice\_service\_network\_association](#output\_vpc\_lattice\_service\_network\_association) | DEPRECATED: v4-compatible full VPC Lattice association object. Use vpc\_lattice\_service\_network\_association\_id. Removed in v6. |
| <a name="output_vpc_lattice_service_network_association_id"></a> [vpc\_lattice\_service\_network\_association\_id](#output\_vpc\_lattice\_service\_network\_association\_id) | VPC Lattice Service Network VPC association ID, or null when disabled. |
<!-- END_TF_DOCS -->