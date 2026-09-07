# Manage subnets in an existing VPC

This example creates a VPC, Internet Gateway, public route table, and Elastic IPs outside the module, then injects those resources while the module creates subnets and a Regional NAT Gateway. Use it to establish a create-or-inject ownership boundary without creating duplicate VPC-level infrastructure.

## What this demonstrates

- `vpc.create = false` returns the injected VPC through the same stable outputs as a module-created VPC.
- `igw_create = false` injects an existing Internet Gateway for managed public routes.
- Public subnets share an injected route table through `manage_route_table = false` and `route_table_id`.
- Existing Elastic IPs are associated with the module-created Regional NAT Gateway but remain outside the module's resource collection.
- Private application subnets retain module-managed route tables and Regional NAT routes.

## Relevant configuration

The complete ownership boundary is in [`main.tf`](./main.tf). The injection and mixed route-table declarations are the distinguishing portion:

```hcl
vpc = {
  name       = "existing-vpc-boundary"
  create     = false
  id         = aws_vpc.external.id
  igw_create = false
  igw_id     = aws_internet_gateway.external.id
}

subnets = {
  public = {
    role = "public"
    ipv4 = {
      cidrs_by_az = {
        for index, az in var.availability_zones :
        az => cidrsubnet(var.vpc_cidr, 8, index)
      }
    }
    manage_route_table = false
    route_table_key    = "external-public"
    route_table_id     = aws_route_table.public.id
    routing = {
      internet_gateway = true
    }
  }
}

nat_gateway = {
  mode = "regional"
  eip = {
    mode = "existing"
    allocation_ids = {
      for az, eip in aws_eip.nat : az => eip.id
    }
  }
}
```

## Prerequisites and cost

- Terraform `>= 1.5` and AWS provider `>= 6.29`.
- AWS credentials with permissions to create the root-owned VPC resources plus module-owned subnets, route tables, routes, and NAT Gateways.
- Exactly two distinct Availability Zones in the selected Region.
- In an existing environment, replace the root `aws_*` resources with references to infrastructure owned by the appropriate state and coordinate route-table changes with that owner.
- **Cost:** one Regional NAT Gateway billed across two active AZs, two public IPv4 addresses, data processing, and regional data transfer can incur charges.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output module_ownership
terraform output nat_gateway_evidence
terraform output route_table_ids
terraform destroy
```

`module_ownership` should report zero module-created VPCs, Internet Gateways, and Elastic IPs; this standalone example still destroys the injected resources because its root configuration creates and owns them.
