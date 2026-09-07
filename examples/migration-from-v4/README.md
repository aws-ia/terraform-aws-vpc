# Rehearse a migration from v4

This example preserves representative v4 names, subnet keys, resource addresses, and Flow Logs ownership while translating configuration to the v5 typed contract. Use it only with a copied caller configuration and isolated state while following the [v5 upgrade guide](../../docs/UPGRADE-GUIDE-5.0.md) and [migration reference](../../docs/migration-v4-reference.md).

## What this demonstrates

- Explicit AZs, CIDRs, and name formats that preserve existing physical resource identity.
- A catalog of `moved` blocks selected by exact source addresses from `terraform state list`.
- Root-level `removed { destroy = false }` and `import` blocks for resources that cannot use `moved`.
- Declarative import of the standalone IPv6 CIDR association when v4 stored that ownership on `aws_vpc.main`.
- Tier 2 compatibility outputs that remain available while consumers move to Tier 1 outputs.

## Relevant configuration

The full v5 skeleton is in [`main.tf`](./main.tf), and the move catalog is in [`moved.tf`](./moved.tf). A caller-root handoff combines only the blocks applicable to its current state:

```hcl
moved {
  from = module.vpc.aws_subnet.public["us-east-1a"]
  to   = module.vpc.aws_subnet.main["public/us-east-1a"]
}

moved {
  from = module.vpc.aws_route_table.public["us-east-1a"]
  to   = module.vpc.aws_route_table.main["public/us-east-1a"]
}

removed {
  from = module.vpc.module.flow_logs.aws_cloudwatch_log_group.main

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.vpc.module.flow_logs.aws_iam_role_policy.flow_logs

  lifecycle {
    destroy = false
  }
}

moved {
  from = module.vpc.module.flow_logs[0].aws_flow_log.main
  to   = module.vpc.aws_flow_log.this["default"]
}

moved {
  from = module.vpc.module.flow_logs[0].aws_iam_role.flow_logs[0]
  to   = module.vpc.aws_iam_role.flow_logs["default"]
}

import {
  to = module.vpc.aws_cloudwatch_log_group.flow_logs["default"]
  id = var.v4_flow_log_group_name
}

import {
  to = module.vpc.aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"]
  id = local.v4_ipv6_import_id
}
```

## Prerequisites and cost

- Terraform `>= 1.7` for `removed` blocks and AWS provider `>= 6.29`.
- Read access to the current backend, state, AWS resources, and provider configuration; use write credentials only for the separately reviewed production apply.
- Exact v4 physical IDs, generated names, IAM role prefixes, AZ ordering, subnet CIDRs, and IPv6 association data captured before translation.
- An isolated backend or workspace containing a protected copy of state. A copied state still references real AWS resources, so never apply or destroy from the rehearsal workspace.
- **Cost:** initialization, validation, and planning create no resources. Applying this sample unchanged can disrupt live ownership and is not supported.

## Rehearse safely

1. Copy the caller configuration and state into an isolated backend or workspace, then protect the original state with normal backend versioning and retention.
2. Replace every placeholder in `main.tf` with values observed from the v4 configuration, state, and AWS APIs.
3. Copy `moved.tf` into the caller root, retain only blocks whose source addresses exist, and repeat keyed blocks for every real private group and AZ.
4. Add only the required root `removed` and `import` blocks, including the IPv6 association import when the v4 VPC has IPv6.
5. Run the complete normal-plan gate and reject any replacement, destroy, unexpected tag change, or IPv6 disassociation.

```shell
terraform init
terraform validate
terraform state pull > before.tfstate
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
```

Do not apply the rehearsal plan; perform the production apply only through the upgrade runbook after resource-address, physical-ID, IAM, Flow Logs delivery, and rollback checks all pass.
