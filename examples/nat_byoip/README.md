# NAT Gateway Elastic IP ownership modes

This example compares four independent VPC deployments that exercise module-created Elastic IPs, BYOIP allocation, existing Elastic IP injection, and Regional NAT Gateway mode. Use it to choose an explicit public IPv4 ownership model before adopting a NAT topology.

## What this demonstrates

- `eip.mode = "create"` lets the module allocate one public Elastic IP per zonal NAT Gateway.
- `eip.mode = "byoip_pool"` allocates module-owned Elastic IPs from a caller-supplied BYOIP pool.
- `eip.mode = "existing"` injects caller-owned allocation IDs keyed by Availability Zone.
- `mode = "regional"` creates a Regional NAT Gateway and does not require a public subnet group.
- Regional `eip.mode = "create"` delegates IP and active-AZ management to AWS; the example uses existing allocation IDs to demonstrate manual addressing.

## Relevant configuration

The complete four-VPC comparison is in [`main.tf`](./main.tf). The differential NAT blocks are:

```hcl
module "create" {
  source = "../.."

  nat_gateway = {
    mode         = "all_azs"
    subnet_group = "public"
    eip          = { mode = "create" }
  }
}

module "byoip_pool" {
  source = "../.."

  nat_gateway = {
    mode         = "all_azs"
    subnet_group = "public"
    eip = {
      mode             = "byoip_pool"
      public_ipv4_pool = var.public_ipv4_pool
    }
  }
}

module "existing" {
  source = "../.."

  nat_gateway = {
    mode         = "all_azs"
    subnet_group = "public"
    eip = {
      mode           = "existing"
      allocation_ids = var.existing_eip_allocation_ids
    }
  }
}

module "regional_existing" {
  source = "../.."

  nat_gateway = {
    mode = "regional"
    eip = {
      mode           = "existing"
      allocation_ids = var.existing_eip_allocation_ids
    }
  }
}
```

## Prerequisites and cost

- Terraform `>= 1.5` and AWS provider `>= 6.29`.
- AWS credentials with permissions to create four VPCs, subnets, route tables, NAT Gateways, and Elastic IPs.
- A provisioned BYOIP public IPv4 pool for `public_ipv4_pool`.
- One existing, unassociated Elastic IP allocation ID per selected AZ for `existing_eip_allocation_ids`; the same map is also supplied to the Regional NAT deployment.
- Regional NAT Gateway must be available in the selected Region and account.
- **Cost:** with the default two AZs, this example creates six zonal NAT Gateways plus one Regional NAT Gateway and may allocate four additional public IPv4 addresses. NAT hourly, processing, data-transfer, and public IPv4 charges apply. Existing and BYOIP addresses remain caller-owned and are not released by the module.

## Run

Create `nat-byoip.tfvars` with real external resources:

```hcl
public_ipv4_pool = "ipv4pool-ec2-0123456789abcdef0"
existing_eip_allocation_ids = {
  "us-east-1a" = "eipalloc-0123456789abcdef0"
  "us-east-1b" = "eipalloc-0123456789abcdef1"
}
```

```shell
terraform init
terraform validate
terraform plan -out=tfplan -var-file=nat-byoip.tfvars
terraform apply tfplan
terraform output nat_gateway_ids_by_case
terraform output eip_ownership_by_case
terraform destroy -var-file=nat-byoip.tfvars
```

Compare `eip_ownership_by_case` after apply: `create` and `byoip_pool` should report module-owned Elastic IPs, while `existing` and `regional_existing` should report injected allocation IDs. Destruction removes module-created NAT Gateways and addresses but leaves injected Elastic IPs and the BYOIP pool intact.
