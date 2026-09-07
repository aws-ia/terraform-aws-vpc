# Security and operations

Security controls in this module are explicit and independently owned. Reading an AWS-created default resource is not the same as adopting it, and account- or Region-wide controls require one designated state owner.

## Default resource observation and adoption

AWS creates a default security group, network ACL, and route table with every VPC. The module always observes their IDs and exposes them through `default_resource_ids`; observation does not change lifecycle or configuration.

`default_resources` is an opt-in adoption contract:

```hcl
default_resources = {
  manage_security_group = true
  manage_network_acl    = true
  manage_route_table    = true
  tags = {
    SecurityBoundary = "managed-defaults"
  }
}
```

Enabling a selector takes ownership of the existing AWS-created resource rather than creating a replacement:

- security-group adoption removes default ingress and egress rules;
- network-ACL adoption removes default allow rules;
- route-table adoption removes non-local routes and gateway propagation.

All selectors default to false. Inventory live dependencies and migrate workloads to explicit security groups, ACLs, and route tables before adoption. Disabling management later releases Terraform ownership behavior but does not reconstruct rules that adoption removed.

## Network ACLs

A subnet group's optional `network_acl` owns or injects one ACL, manages declared rules, and associates every subnet in the group. Omission preserves AWS default-ACL behavior.

Ingress and egress maps are keyed by the actual AWS rule number:

```hcl
network_acl = {
  ingress = {
    "100" = {
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "10.0.0.0/8"
      from_port  = 443
      to_port    = 443
    }
  }
}
```

Rule-number keys are Terraform state identity. Use canonical integer strings from `1` through `32766`, preserve them after deployment, and introduce new rules with deliberate numeric spacing.

Network ACLs are stateless. Every permitted request path needs a separate reverse-direction rule, including ephemeral ports. Prefer security groups when stateful workload identity is sufficient; use ACLs for deliberate subnet-boundary controls and test both directions.

Inject mode uses `create = false` plus `id`. The module does not own the ACL itself but still owns every declared rule and subnet association.

## VPC Block Public Access

`vpc_block_public_access` manages an account-and-Region singleton. Enable it from exactly one module instance or inject an existing options ID from the designated owner.

```hcl
vpc_block_public_access = {
  enabled                     = true
  internet_gateway_block_mode = "block-bidirectional"
}
```

Supported block modes are `block-ingress` and `block-bidirectional`. Stable-keyed exclusions can target the VPC or one subnet and independently support create or inject ownership. `allow-egress` exclusions require bidirectional blocking.

A BPA change can affect VPCs beyond the module instance that declares it. Review all VPCs in the Region before apply and define who preserves the desired Regional setting when this module is destroyed or transferred.

## VPC Flow Logs

`flow_logs` is keyed by stable logical identity. Each entry independently selects Flow Log ownership, destination type, destination ownership, and—when CloudWatch is used—IAM role ownership.

| Destination | Ownership contract |
| --- | --- |
| CloudWatch Logs | The module can create or inject the log group and IAM role. |
| Amazon S3 | Bucket, KMS, retention, and lifecycle remain externally owned; supply `destination_arn`. |
| Kinesis Data Firehose | Delivery stream and its S3/IAM dependencies remain externally owned; supply `destination_arn`. |

```hcl
flow_logs = {
  audit = {
    destination_type = "cloudwatch"
    traffic_type     = "ALL"
    cloudwatch_options = {
      retention_in_days = 365
      kms_key_id        = aws_kms_key.logs.arn
    }
  }
}
```

CloudWatch injection uses `create_destination = false` with `destination_arn` and/or `create_iam_role = false` with `iam_role_arn`. Injected destinations and roles retain their existing lifecycle owner. S3 and Firehose never become child resources of this module.

Map keys control Flow Log state addresses. Preserve a deployed key or use a caller-root `moved` block. Use `log_format`, traffic type, aggregation interval, retention, KMS, and cross-account delivery fields as operational controls and review changes for cost and data-retention impact.

The migration-specific CloudWatch ownership handoff is documented in the [upgrade guide](UPGRADE-GUIDE-5.0.md).

## DHCP options

`dhcp_options.enabled` associates either a module-created or injected option set with the VPC. Create mode accepts domain, DNS, NTP, NetBIOS, and IPv6 preferred-lease settings; inject mode uses `create = false` plus `id`.

```hcl
dhcp_options = {
  enabled             = true
  domain_name         = "internal.example"
  domain_name_servers = ["AmazonProvidedDNS"]
  ntp_servers         = ["169.254.169.123"]
}
```

Review name-resolution behavior before changing an associated option set. DHCP changes affect instances as leases renew and can have a longer operational tail than the Terraform apply.

## Tags and names

Effective tag precedence is:

1. AWS provider `default_tags`;
2. module-level `tags`;
3. VPC, group, or resource-specific tags;
4. the module-generated `Name` tag.

More specific entries override earlier entries. Keep provider `default_tags` stable during migrations so provider tag drift is not mixed with module state changes.

Name formats change display tags but do not change caller-owned map keys. Use format fields for naming and `moved` blocks for actual key migrations.

## Operational checklist

- Treat default-resource management as adoption of live resources, not creation of replacements.
- Preserve NACL rule-number keys and test stateless return paths.
- Assign VPC Block Public Access to one account/Region state owner.
- Keep durable log destinations outside the VPC module unless using its native CloudWatch path.
- Encrypt and retain logs according to organizational policy, and verify delivery after IAM or destination changes.
- Review DHCP changes for lease-renewal impact.
- Include log ingestion, retention, KMS, Firehose, S3, public IPv4, NAT, and transfer charges in operating estimates.
