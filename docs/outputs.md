# Output contracts

The module groups outputs into three tiers so consumers can choose between a stable public contract, temporary v4 compatibility, and an unstable escape hatch. New integrations should start with Tier 1.

## Choose the lowest tier that solves the integration

| Tier | Intended use | Compatibility |
| --- | --- | --- |
| Tier 1 — stable handles | Normal composition through IDs, ARNs, CIDRs, and maps keyed by group/role/AZ | Names, value types, and existing collection keys are semver-protected. Minor releases may add outputs or map keys. |
| Tier 2 — deprecated v4 aliases | Keeping v4 consumers operational during a staged v5 migration | Preserved for v5 and removed in v6. Values are full provider objects and provider-controlled attributes may change. |
| Tier 3 — `resources` | Accessing a provider attribute that Tier 1 does not expose | No semver guarantee; collection shape or attributes may change in any release. |

If an integration can use a Tier 1 ID instead of an object, use the ID. This keeps downstream plans independent of provider schema additions, removals, and deprecations.

## Tier 1: stable composition

### Allow traffic from every IPv4 VPC CIDR

`vpc_ipv4_cidr_blocks` contains `primary` plus every IPv4 key from
`addressing.secondary`. The keys are stable even when an IPAM-allocated value is
unknown during planning. Provider-assigned IPAM values are passed through without
being coerced to `null` and resolve after apply; `null` is reserved for an injected
association that AWS does not resolve.

Using the map directly as `for_each` preserves resource identity while allowing
provider-computed CIDRs to remain unknown until apply:

```hcl
resource "aws_security_group" "service" {
  name   = "service"
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "vpc_https" {
  for_each = module.vpc.vpc_ipv4_cidr_blocks

  description       = "HTTPS from VPC CIDR ${each.key}"
  security_group_id = aws_security_group.service.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}
```

IPv6 secondary keys do not appear in this map; use `vpc_ipv6_cidr_blocks` for
those associations.

### Select subnets by caller-owned group

Group keys are the keys supplied in `var.subnets`. Use them when the consumer knows the topology name. The fragment below omits required module inputs.

```text
module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = "~> 5.0"

  # ...
  subnets = {
    application = {
      role = "private"
      # ...
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = values(module.vpc.route_table_ids_by_group_by_az.application)
}
```

Useful group outputs are:

- `subnet_ids_by_group`: `map(group, list(subnet_id))`;
- `subnet_ids_by_group_by_az`: `map(group, map(az, subnet_id))`;
- `subnet_cidrs_by_group_by_az`: IPv4 CIDRs with `null` for subnets without IPv4;
- `subnet_ipv6_cidrs_by_group_by_az`: IPv6 CIDRs with `null` for subnets without IPv6;
- `route_table_ids_by_group_by_az`: route tables with the same group/AZ keys.

The IPv6 null sentinel is deliberate and stable:

```hcl
locals {
  ipv6_enabled_subnets = {
    for az, cidr in module.vpc.subnet_ipv6_cidrs_by_group_by_az.application :
    az => cidr if cidr != null
  }
}
```

Do not test for an empty string. v5 normalizes provider empty-string values to `null` at the Tier 1 boundary.

### Select subnets by semantic role

Use semantic-role outputs when a reusable consumer cares about behavior rather than the caller's group names:

```hcl
resource "aws_security_group" "application" {
  name   = "application"
  vpc_id = module.vpc.vpc_id
}

locals {
  private_subnet_ids = module.vpc.subnet_ids_by_semantic_role.private
}
```

Multiple groups may share a role, so per-role/per-AZ outputs contain lists:

```hcl
locals {
  private_subnets_in_first_az = module.vpc.subnet_ids_by_semantic_role_by_az.private[var.availability_zones[0]]
}
```

The stable role keys are `public`, `private`, `isolated`, `transit_gateway`, and `core_network`; an unused role returns an empty collection rather than disappearing.

### Compose NAT, gateway, attachment, and logging resources

```hcl
resource "aws_route53_resolver_endpoint" "outbound" {
  name      = "outbound"
  direction = "OUTBOUND"

  dynamic "ip_address" {
    for_each = module.vpc.subnet_ids_by_group_by_az.endpoints
    content {
      subnet_id = ip_address.value
    }
  }

  security_group_ids = [aws_security_group.resolver.id]
}

locals {
  nat_ids                       = module.vpc.nat_gateway_ids
  internet_gateway_id            = module.vpc.internet_gateway_id
  tgw_attachment_ids             = module.vpc.transit_gateway_attachment_ids
  vpc_ipv6_cidr_blocks           = module.vpc.vpc_ipv6_cidr_blocks
  secondary_ipv4_association_ids = module.vpc.secondary_ipv4_cidr_association_ids
  secondary_ipv6_association_ids = module.vpc.secondary_ipv6_cidr_association_ids
  audit_flow_log_id              = module.vpc.flow_log_ids["audit"]
}
```

Optional singleton handles return `null`; optional collections return `{}`. Test the documented shape rather than catching arbitrary errors with `try`:

```hcl
locals {
  has_eigw = module.vpc.egress_only_igw_id != null
  has_nat  = length(module.vpc.nat_gateway_ids) > 0
}
```

## Tier 2: migrate v4 consumers, then remove them

Tier 2 aliases retain v4 names and outer keys so a module upgrade and downstream refactor can be separate changes. The following is an attribute fragment rather than a complete root module:

```text
# Temporary v4-compatible dependency during migration.
subnet_id = module.vpc.private_subnet_attributes_by_az["application/us-east-1a"].id

# Final Tier 1 dependency.
subnet_id = module.vpc.subnet_ids_by_group_by_az.application["us-east-1a"]
```

Exact compatibility requires migrated reserved group names (`public`, `transit_gateway`, and `core_network`) and the Flow Log key `default`. Tier 2 values intentionally expose full provider objects, so they are not a safe contract for new code. Track their removal before upgrading to v6.

The v4-to-v5 mapping and state procedure are in [Upgrade guide 5.0](UPGRADE-GUIDE-5.0.md).

## Tier 3: use the escape hatch deliberately

`resources` exposes internal collections for advanced composition:

```hcl
locals {
  application_subnet_tags = module.vpc.resources.subnets["application/us-east-1a"].tags_all
}
```

Treat every Tier 3 reference as coupled to this module's implementation and the AWS provider schema. Encapsulate it in one local and document why Tier 1 is insufficient.

`resources.flow_log_roles` is intentionally **not** a complete `aws_iam_role` object. Each entry is projected to the useful, non-deprecated attributes:

```text
{
  arn       = string
  id        = string
  name      = string
  unique_id = string
}
```

The projection prevents evaluation of the provider's deprecated `inline_policy` attribute. Inline policy lifecycle remains available separately through `resources.flow_log_role_policies`. No other Tier 3 collection exports complete `aws_iam_role` objects.

## Explore outputs safely

After `terraform plan` or `terraform apply`, inspect values without copying provider objects into new outputs:

```shell
terraform output
terraform console
```

Examples in the console:

```console
module.vpc.subnet_ids_by_group_by_az
module.vpc.subnet_ids_by_semantic_role.private
module.vpc.route_table_ids_by_group_by_az.application
module.vpc.subnet_ipv6_cidrs_by_group_by_az
```

For automation, prefer JSON:

```shell
terraform output -json vpc_id
terraform output -json subnet_ids_by_group_by_az
```

## Consumer checklist

- Prefer Tier 1 IDs/ARNs/CIDRs over full resource objects.
- Choose group outputs for topology-specific code and role outputs for reusable code.
- Preserve caller map keys; they are collection identity, not display labels.
- Handle optional scalar values as `null` and optional collections as empty maps/lists.
- Treat `subnet_ipv6_cidrs_by_group_by_az` non-IPv6 values as `null`, never `""`.
- Use Tier 2 only during v4 migration and plan its removal before v6.
- Isolate Tier 3 references and expect them to change outside semver guarantees.
