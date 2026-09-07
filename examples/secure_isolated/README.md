# Isolated VPC security boundary

This example creates two isolated subnet tiers with explicit network ACL rules, hardened default VPC resources, custom DHCP options, and Regional VPC Block Public Access. Use it for workloads that require a fail-closed network boundary with no Internet Gateway, NAT Gateway, egress-only gateway, or transit route.

## What this demonstrates

- Isolated subnet roles create route tables without managed egress routes.
- Caller-owned NACL rule-number keys provide stable state identity for stateless ingress and egress rules.
- AWS-created default security group, network ACL, and route table resources are explicitly adopted and hardened.
- Custom DHCP options are created and associated with the VPC.
- Regional VPC Block Public Access is enabled in bidirectional mode from one designated module instance.

## Relevant configuration

The complete configuration is in [`main.tf`](./main.tf). The enclave ACL and Regional public-access control are the security-specific declarations:

```hcl
subnets = {
  enclave = {
    role = "isolated"
    ipv4 = {
      cidrs_by_az = {
        for index, az in var.availability_zones :
        az => cidrsubnet(var.vpc_cidr, 8, index)
      }
    }
    network_acl = {
      ingress = {
        "100" = {
          protocol   = "tcp"
          action     = "allow"
          cidr_block = cidrsubnet(var.vpc_cidr, 4, 1)
          from_port  = 443
          to_port    = 443
        }
      }
      egress = {
        "100" = {
          protocol   = "tcp"
          action     = "allow"
          cidr_block = cidrsubnet(var.vpc_cidr, 4, 1)
          from_port  = 1024
          to_port    = 65535
        }
      }
      tags = { DataClassification = "restricted" }
    }
  }
}

vpc_block_public_access = {
  enabled                     = true
  internet_gateway_block_mode = "block-bidirectional"
}
```

## Prerequisites and cost

- Terraform `>= 1.5` and AWS provider `>= 6.29`.
- AWS credentials with permissions for VPC networking, default-resource adoption, DHCP options, NACLs, and account-level VPC Block Public Access options.
- Exactly two distinct Availability Zones in the selected Region.
- Regional VPC Block Public Access is an account-and-Region singleton with broader impact than this VPC. Manage it from exactly one state after reviewing every VPC in the Region.
- **Cost:** this configuration creates no NAT Gateway, public IPv4 address, or managed logging destination. Standard data-transfer and any services later attached to the VPC can still incur charges.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output egress_resources
terraform output network_acl_controls
terraform destroy
```

Before destroy, confirm another state or operational control will retain the intended Regional public-access posture; removing this module's singleton setting can affect VPCs beyond the example.
