# VPC and subnet allocation from IPAM

This example allocates primary and secondary VPC CIDRs plus IPv4, IPv6, and IPv6-native subnets from caller-supplied IPAM pools. Use it when centralized address management must coexist with a static legacy range and stable caller-owned association keys.

## What this demonstrates

- A primary IPv4 `/16` and named secondary IPv4 `/20` allocated from different VPC IPAM pools.
- A static `legacy` secondary CIDR alongside IPAM-managed associations.
- IPv4 and IPv6 subnet allocation from dedicated subnet pools.
- The `analytics`, `legacy`, and `ipv6-ipam` keys as persistent Terraform state identity.
- An IPv6-native subnet group with no IPv4 allocation.

## Relevant configuration

The complete configuration is in [`main.tf`](./main.tf). The parent and subnet pool selections are the distinguishing declarations:

```hcl
addressing = {
  primary = {
    ipam_pool_id   = var.vpc_ipv4_ipam_pool_id
    netmask_length = 16
  }
  secondary = {
    analytics = {
      ipv4 = {
        ipam_pool_id   = var.secondary_ipv4_ipam_pool_id
        netmask_length = 20
      }
    }
    legacy = {
      ipv4 = { cidr_block = "100.64.0.0/20" }
    }
    ipv6-ipam = {
      ipv6 = {
        ipam_pool_id   = var.vpc_ipv6_ipam_pool_id
        netmask_length = 56
      }
    }
  }
}

subnets = {
  application = {
    role = "private"
    ipv4 = {
      ipam_pool_id   = var.subnet_ipv4_ipam_pool_id
      netmask_length = 24
    }
    ipv6 = {
      secondary_cidr_key = "ipv6-ipam"
      ipam_pool_id       = var.subnet_ipv6_ipam_pool_id
      netmask_length     = 64
      auto_assign        = true
    }
  }
}
```

## Prerequisites and cost

- Terraform `>= 1.5` and AWS provider `>= 6.29`.
- AWS credentials with permission to allocate from every referenced IPAM pool and to create VPCs and subnets.
- Existing IPv4 and IPv6 IPAM pools shared with the executing account where necessary; provide real pool IDs in `ipam.tfvars`.
- Subnet pools must be correctly scoped under the selected VPC pools. The module validates known relationships but cannot prove every IPAM ancestry relationship exhaustively during planning.
- **Cost:** VPC IPAM Advanced Tier charges can apply to managed active IP addresses; standard data-transfer charges also apply to workloads later placed in these subnets.

## Run

Create `ipam.tfvars` with pool IDs from the selected Region:

```hcl
vpc_ipv4_ipam_pool_id             = "ipam-pool-0123456789abcdef0"
secondary_ipv4_ipam_pool_id       = "ipam-pool-1123456789abcdef0"
subnet_ipv4_ipam_pool_id          = "ipam-pool-2123456789abcdef0"
secondary_subnet_ipv4_ipam_pool_id = "ipam-pool-3123456789abcdef0"
vpc_ipv6_ipam_pool_id             = "ipam-pool-4123456789abcdef0"
subnet_ipv6_ipam_pool_id          = "ipam-pool-5123456789abcdef0"
```

```shell
terraform init
terraform validate
terraform plan -out=tfplan -var-file=ipam.tfvars
terraform apply tfplan
terraform output vpc_cidr_block
terraform output subnet_ipv6_cidrs
terraform destroy -var-file=ipam.tfvars
```

Allocated subnet CIDRs may remain unknown until apply; treat an AWS pool-scope or allocation failure as an address-plan error and correct the pool hierarchy rather than forcing the state.
