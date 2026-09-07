# Upgrade guide: terraform-aws-vpc v4 to v5

> **Production migration runbook.** Rehearse every step against a copy of production state and keep a recoverable state backup before each address transition. The v5 module cannot generate caller-specific `moved` blocks because Terraform addresses cannot contain variables or wildcards.
>
> Use the [v4 migration reference](migration-v4-reference.md) for name formulas, input and output crosswalks, state-address rules, and ownership handoffs. The executable catalog is [`examples/migration-from-v4/moved.tf`](../examples/migration-from-v4/moved.tf).

## Contents

- [Migration safety contract](#migration-safety-contract)
- [A. Baseline Terraform and the AWS provider while still on v4](#a-baseline-terraform-and-the-aws-provider-while-still-on-v4)
- [B. Capture v4 identity and ordering](#b-capture-v4-identity-and-ordering)
- [C. Translate configuration and state](#c-translate-configuration-and-state)
- [D. Complete-plan gate](#d-complete-plan-gate)
- [E. Ordered IAM permissions cutover and cleanup](#e-ordered-iam-permissions-cutover-and-cleanup)
- [F. Post-apply verification](#f-post-apply-verification)
- [Stop and rollback](#stop-and-rollback)

## Migration safety contract

- Work against a copy of production state first; never combine an unreviewed provider upgrade with the v4 -> v5 module cutover.
- The migration gate is one saved, complete normal `terraform plan`; no partial or state-only plan is an acceptance substitute.
- Preserve every durable physical ID. The default gate permits zero replacements and zero destroys. Expected creates are built-in `terraform_data` precondition records plus the Flow Logs inline policy described below; `terraform_data` has no AWS API side effects. The v4.8.0 inline policy is forgotten without destroy and cleaned explicitly only after delivery verification.
- Preserve v4 Name tags with the format mapping in the [migration reference](migration-v4-reference.md). Besides eliminating 14 subnet/route-table/EIP/NAT updates in the documented two-AZ topology, set the Flow Log format to `{vpc}` and the log-group format to empty so neither logging resource changes `Name`.
- Keep provider `default_tags` unchanged through the cutover. Duplicate keys resolve provider defaults < module globals < resource/group tags < generated Name.
- Express the CloudWatch log-group ownership handoff declaratively so the old-address forget and the v5-address import are visible in the same normal plan.

## Migration sequence

### A. Baseline Terraform and the AWS provider while still on v4

1. Pin the current v4 module version and back up state outside the repository:

   ```shell
   terraform state pull > /secure/backup/vpc-v4-before-provider-upgrade.tfstate
   terraform state list > /secure/backup/vpc-v4-addresses.txt
   ```

2. Still using v4 configuration, upgrade only the intended Terraform/AWS provider versions. Run a **normal** plan, review/apply provider-only changes, and repeat until clean:

   ```shell
   terraform init -upgrade
   terraform plan -out=v4-provider-upgrade.tfplan
   terraform apply v4-provider-upgrade.tfplan
   terraform plan -detailed-exitcode
   # Required result: exit code 0.
   ```

   Commit the provider lock change separately. Do not change the module source/version in this step. Configure and converge any AWS provider `default_tags` change here, while still on v4. The provider merges defaults below explicit resource tags and exposes the union as `tags_all`; changing defaults after the module switch would mix provider tag drift with migration actions.

### B. Capture v4 identity and ordering

3. Record physical IDs, route destinations, optional resources, subnet keys/CIDRs, Name tags, tag maps, and the exact observable AZ order. `availability_zones.names` and every explicit CIDR list in v5 must use this order; do not reconstruct it from the textual v4 input:

   ```shell
   terraform console <<<'module.vpc.azs'
   terraform state list
   ```

4. For a v4.8.0-created CloudWatch Flow Logs destination, capture the generated log-group name, IAM role name/prefix, and inline-policy name **before** changing module versions:

   ```shell
   terraform state show \
     'module.vpc.module.flow_logs[0].aws_cloudwatch_log_group.main[0]'
   terraform state show \
     'module.vpc.module.flow_logs[0].aws_flow_log.main'
   terraform state show \
     'module.vpc.module.flow_logs[0].aws_iam_role.flow_logs[0]'
   terraform state show \
     'module.vpc.module.flow_logs[0].aws_iam_role_policy.flow_logs[0]'
   ```

   Copy the log group's `name` to `flow_logs.default.cloudwatch_options.name` and to the declarative import ID. Copy the role's `name_prefix` (not its generated `name`) to `flow_logs.default.role_name_prefix`. Retain the generated role `name` and inline-policy `name` for the post-verification cleanup. v4.8.0 uses an inline IAM policy; it does not create the managed policy and role-policy attachment found in older v4 layouts. Always select handoff blocks from the exact addresses returned by `terraform state list`. Both log-group and role naming attributes are ForceNew when configured, so exact identity is required for a zero-replacement cutover.

   If v4 assigned IPv6, also capture `ipv6_association_id`, `ipv6_cidr_block`,
   `ipv6_ipam_pool_id`, and `ipv6_netmask_length` from
   `module.vpc.aws_vpc.main[0]`. v4 stores this association inside the VPC
   resource state, while v5 owns it as a standalone keyed resource; Terraform
   cannot express that ownership transfer with a `moved` block. Preserve every
   observed value exactly. In particular, v4/provider 6.59 permits an IPAM pool
   without an explicit netmask when the pool defines `allocation_default_netmask`;
   v5 represents that case with the observed `ipv6_cidr_block` plus
   `ipv6_ipam_pool_id`, not with a pool-only configuration.

   ```shell
   terraform state show 'module.vpc.aws_vpc.main[0]'
   # Record ipv6_association_id/ipv6_cidr_block and, for IPAM,
   # ipv6_ipam_pool_id plus ipv6_netmask_length when present.
   ```

### C. Translate configuration and state

5. Translate inputs using the [migration reference](migration-v4-reference.md). Keep the v4 group keys initially: `public`, `transit_gateway`, `core_network`, and each private group name. Use explicit current subnet CIDRs and the observed AZ order. Configure the exact v4 Name formats before planning: subnet groups use `"{group}-{az}"`, NAT/EIP use `"nat-{group}-{az}"`, IGW uses `"{vpc}-igw"`, EIGW uses `"{vpc}"`, the Flow Log uses `flow_logs.default.name_format = "{vpc}"`, and its generated log group uses `cloudwatch_options.name_format = ""`.
6. Copy the active `examples/migration-from-v4/moved.tf` into the caller root. Replace sample AZs, private groups, and destination-derived keys. Treat 63 as the union of documented features, not a required count: compare against `terraform state list`, remove every block whose source is absent, and repeat the private six-block pattern for each actual private group. The example intentionally excludes the v4 CloudWatch log group.
7. Change the module source/version and initialize v5 without changing the already-baselined provider selection:

   ```shell
   terraform init
   ```

8. Add two non-destructive `removed` blocks for the v4.8.0 log group and inline policy, plus one declarative `import` block for the v5 log-group address alongside the caller's module block. If v4 assigned IPv6, add the second declarative import shown below for the standalone v5 association. These are root-module blocks; do not place them inside the VPC module. Replace the Flow Logs value in every migration; for IPv6 replace the association ID and observed CIDR, plus the pool ID for IPAM and the netmask only when it was present in v4 state:

   ```hcl
   variable "v4_flow_log_group_name" {
     type    = string
     default = "replace-with-the-generated-v4-log-group-name"
   }

   variable "v4_ipv6_association_id" {
     type    = string
     default = "vpc-cidr-assoc-replace-with-v4-association-id"
   }

   variable "v4_ipv6_cidr_block" {
     type     = string
     default  = null
     nullable = true
   }

   variable "v4_ipv6_ipam_pool_id" {
     type     = string
     default  = null
     nullable = true
   }

   variable "v4_ipv6_netmask_length" {
     type     = number
     default  = null
     nullable = true
   }

   locals {
     v4_ipv6_import_id = join(",", compact([
       var.v4_ipv6_association_id,
       var.v4_ipv6_ipam_pool_id,
       var.v4_ipv6_netmask_length == null ? null : tostring(var.v4_ipv6_netmask_length),
     ]))
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

   import {
     to = module.vpc.aws_cloudwatch_log_group.flow_logs["default"]
     id = var.v4_flow_log_group_name
   }

   # Include only when the v4 VPC has IPv6.
   import {
     to = module.vpc.aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"]
     id = local.v4_ipv6_import_id
   }
   ```

   Set the optional values to reproduce the provider's exact importer form:

   | v4 IPv6 source | Import ID |
   |---|---|
   | Amazon-provided | `association_id` |
   | IPAM with explicit CIDR | `association_id,ipv6_ipam_pool_id` |
   | IPAM with netmask | `association_id,ipv6_ipam_pool_id,ipv6_netmask_length` |

   Configure `addressing.secondary["v4-ipv6"].ipv6` from the same captured
   values. These are module-argument fragments, not standalone roots:

   ```text
   # Amazon-provided
   { amazon_assigned = true }

   # IPAM with explicit CIDR, including a v4 pool-default allocation
   { ipam_pool_id = var.v4_ipv6_ipam_pool_id, cidr_block = var.v4_ipv6_cidr_block }

   # IPAM with an explicit netmask in v4 state
   { ipam_pool_id = var.v4_ipv6_ipam_pool_id, netmask_length = var.v4_ipv6_netmask_length }
   ```

   For the pool-default case, the v5 configuration uses the second form and the
   importer uses the two-component `association_id,pool_id` form. Do not copy the
   v4 pool-only input into v5: it is intentionally rejected because v5 requires
   the observed allocation identity or an explicit netmask.

   A one-component ID is valid only for Amazon-provided IPv6. Using it for IPAM drops ForceNew pool/netmask state and produces a replacement plan.

   `removed.from` addresses resources, not resource instances: Terraform Core rejects the `[0]` module and resource instance keys from the v4.8.0 state addresses. Omitting those keys matches every instance selected by the configuration; the indexed addresses remain valid for `terraform state show` and the IAM-role `moved` block.

   Declarative import requires Terraform >= 1.5; non-destructive `removed` requires Terraform >= 1.7. Therefore this ownership-preserving migration procedure has a Terraform >= 1.7 runner floor even though the v5 module itself remains compatible with Terraform >= 1.5. Keep the IAM role moved block active and preserve its exact `role_name_prefix`.

   The v5 `aws_vpc.main` resource deliberately ignores its four legacy embedded IPv6 fields: `assign_generated_ipv6_cidr_block`, `ipv6_cidr_block`, `ipv6_ipam_pool_id`, and `ipv6_netmask_length`. This lifecycle bridge is mandatory. Without it, AWS provider 6.59 treats removal of the v4 arguments as an update and disassociates the live prefix even if the standalone resource is imported in the same plan. The bridge suppresses that physical mutation while the standalone keyed resource acquires ownership.

   The complete normal plan in section D evaluates the v5 configuration, all selected moves, two non-destructive forgets, the log-group import, and the optional IPv6 association import together; there is no preliminary state-materialization plan or CLI state surgery. The plan must show no change at `module.vpc.aws_vpc.main[0]`, including no `assign_generated_ipv6_cidr_block = true -> null` update.

### D. Complete-plan gate

9. Run and save a **complete normal plan**:

   ```shell
   terraform plan -out=v5-migration.tfplan
   terraform show -no-color v5-migration.tfplan > v5-migration.txt
   ```

   The gate criteria are:

   - **Required:** zero `destroy` and zero `replace` actions; no create/delete for VPC, subnets, route tables, NAT gateways/EIPs, gateways, attachments, CloudWatch log group, or IAM role; no destruction of S3 buckets or any log archive. `module.vpc.aws_vpc.main[0]` must have no planned update: any removal of embedded IPv6 arguments, especially `assign_generated_ipv6_cidr_block = true -> null`, fails the gate.
   - **Expected state-only transitions:** the selected `moved` pairs, two `removed { destroy = false }` forgets for the v4.8.0 log group/inline policy, one log-group import, and—when v4 IPv6 exists—one import of its existing association into `secondary["v4-ipv6"]`. Re-keyed routes whose destination is unchanged have no residual create/delete.
   - **Allowed creates:** `module.vpc.aws_iam_role_policy.flow_logs["default"]` for a module-created CloudWatch role, plus the expected built-in `terraform_data` precondition records. These records exist only in Terraform state and perform no AWS API operations. For the documented two-AZ topology the exact seven are:
     - `module.vpc.terraform_data.attachment_contract_validation`;
     - `module.vpc.terraform_data.cidrs_az_count_validation["private"]`;
     - `module.vpc.terraform_data.cidrs_az_count_validation["public"]`;
     - `module.vpc.terraform_data.cidrs_az_count_validation["workload"]`;
     - `module.vpc.terraform_data.nat_gateway_az_validation[0]`;
     - `module.vpc.terraform_data.nat_gateway_subnet_group_validation[0]`;
     - `module.vpc.terraform_data.vpc_ipv4_addressing_validation[0]`.
     Other configurations may select a different documented precondition subset; every address must correspond to a `terraform_data` block in the pinned module source.
   - **Expected IAM-role updates, when the v4 role was module-created:** the trust policy removes the legacy `Sid` and adds the desirable confused-deputy protections `aws:SourceAccount=<account-id>` and `aws:SourceArn=arn:<partition>:ec2:<region>:<account-id>:vpc-flow-log/*`; the description changes from `Cloudwatch permissions role for <vpc> with vpc-flow-logs` to `Allows VPC Flow Logs to publish <vpc>/default logs`. The role ID and generated name must remain unchanged.
   - **Other allowed in-place updates, only when explicitly reviewed:** Flow Log traffic type/log format/aggregation interval; CloudWatch retention and KMS key. With the migration Name formats, no Flow Log or log-group `Name` tag update is expected. Keep all other values identical unless the change is separately approved.
   - **Exceptional route residual:** delete/create is allowed only for a route destination deliberately changed during migration, enumerated by address and approved for a maintenance window. With frozen destinations the expected residual is zero.

   Any destroy, any replacement, any unlisted create/delete, or any unexpected `Name` update fails the gate.

### E. Ordered IAM permissions cutover and cleanup

10. Apply the saved complete plan. The v5 inline policy is created while the forgotten v4.8.0 inline policy remains attached to the preserved role because its `removed` block uses `destroy = false`:

    ```shell
    terraform apply v5-migration.tfplan
    ```

11. Verify that `publish-vpc-flow-logs` exists inline on the preserved role and that the existing Flow Log continues delivering events newer than the apply to the preserved log group. Only after both checks pass, delete the forgotten v4.8.0 inline policy using the complete role and policy names captured in step 4:

    ```shell
    export V4_FLOW_LOG_ROLE_NAME='replace-with-generated-role-name'
    export V4_FLOW_LOG_POLICY_NAME='replace-with-v4-inline-policy-name'

    aws iam get-role-policy \
      --role-name "$V4_FLOW_LOG_ROLE_NAME" \
      --policy-name publish-vpc-flow-logs
    aws iam get-role-policy \
      --role-name "$V4_FLOW_LOG_ROLE_NAME" \
      --policy-name "$V4_FLOW_LOG_POLICY_NAME"
    aws iam delete-role-policy \
      --role-name "$V4_FLOW_LOG_ROLE_NAME" \
      --policy-name "$V4_FLOW_LOG_POLICY_NAME"
    ```

    The deliberate trade-off is one temporary inline policy outside Terraform state. This is preferable to a first plan containing a premature policy deletion: Terraform cannot express a graph edge conditioned on successful post-apply log delivery. Record the cleanup output, then require a clean complete plan.

### F. Post-apply verification

12. Compare the saved v4 inventory with v5 state: VPC, subnet, route-table, NAT/EIP, gateway, attachment, Flow Log, log-group, and IAM-role physical IDs must be preserved. Confirm no v4 module addresses remain:

    ```shell
    terraform state list | grep 'module.vpc.module.flow_logs' && exit 1 || true
    terraform state show 'module.vpc.aws_flow_log.this["default"]'
    terraform state show 'module.vpc.aws_cloudwatch_log_group.flow_logs["default"]'
    terraform state show 'module.vpc.aws_iam_role.flow_logs["default"]'
    ```

13. Verify the Flow Log reports `ACTIVE` and that the preserved CloudWatch group receives events newer than the cutover. Finally require a clean complete plan:

    ```shell
    terraform plan -detailed-exitcode
    # Required result: exit code 0.
    ```

14. Migrate downstream references from Tier 2 aliases to Tier 1 handles. Retain the caller's moved file until every workspace has applied the upgrade.

## Stop and rollback

Stop before apply if the complete plan contains any replacement, destroy, unlisted create/delete, unexpected `Name` update, or IPv6 update on `module.vpc.aws_vpc.main[0]`. Correct configuration, state-address mappings, or captured identity and generate a new saved plan; never edit or reuse a rejected plan.

If apply fails, do not perform the legacy IAM cleanup. Preserve the state snapshot, saved plan, apply output, and current AWS resource inventory. Reconcile Terraform state with the physical resources before any retry; restore a state backup only when it accurately represents the unchanged physical resources and the backend owner has approved the recovery.

After a successful apply but failed Flow Logs verification, keep the forgotten v4.8.0 inline policy in place while investigating. Do not delete it until the v5 inline policy exists and events newer than the cutover reach the preserved destination.

Rollback to v4 is a separately reviewed state transition: restore the v4 configuration, reverse only the applied address ownership changes with exact declarative moves/imports, and require a complete zero-destroy plan before applying. Do not point old configuration at newly keyed state without an explicit reverse mapping.

Use the [v4 migration reference](migration-v4-reference.md) for the input/output crosswalks and cases that cannot use `moved` blocks.
