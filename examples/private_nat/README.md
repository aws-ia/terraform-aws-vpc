# Private NAT for overlapping networks

This example creates a two-AZ VPC where workload traffic is translated from `10.42.0.0/16` into a `100.64.0.0/20` secondary range before reaching a Transit Gateway. Use it to connect overlapping private address domains without an Internet Gateway or public Elastic IP.

## What this demonstrates

- Workload route tables use AZ-local private NAT Gateways as their default next hop.
- Dedicated NAT-host subnets consume explicit CIDRs from the named `translation` secondary association.
- NAT-host route tables forward only selected remote CIDRs to the TGW attachment.
- The `vpc` key is shared by route selection and the top-level attachment map as stable state identity.
- `connectivity_type = "private"` creates private NAT Gateways without public addresses.

## Relevant configuration

The complete configuration is in [`main.tf`](./main.tf). The translation and attachment subnets plus private NAT declaration are the distinguishing portion:

```hcl
subnets = {
  nat-host = {
    role = "private"
    ipv4 = {
      cidrs_by_az = {
        "us-west-2a" = "100.64.0.0/28"
        "us-west-2b" = "100.64.0.16/28"
      }
      secondary_cidr_key = "translation"
    }
    routing = {
      transit_gateway_attachments = {
        vpc = var.tgw_destination_cidrs
      }
    }
  }

  tgw = {
    role = "transit_gateway"
    ipv4 = {
      cidrs_by_az = {
        "us-west-2a" = "100.64.0.32/28"
        "us-west-2b" = "100.64.0.48/28"
      }
      secondary_cidr_key = "translation"
    }
  }
}

transit_gateway_attachments = {
  vpc = {
    subnet_group = "tgw"
    id           = var.transit_gateway_id
  }
}

nat_gateway = {
  mode              = "all_azs"
  connectivity_type = "private"
  subnet_group      = "nat-host"
}
```

## Prerequisites and cost

- Terraform `>= 1.5` and AWS provider `>= 6.29`.
- AWS credentials with permissions to create VPC networking, private NAT Gateways, and a TGW VPC attachment.
- An existing Transit Gateway with route-table policy for the translated VPC and return routes toward `100.64.0.0/20`.
- Two distinct `us-west-2` AZs; update every explicit subnet CIDR key together if the AZ set changes.
- **Cost:** two private NAT Gateways, one TGW VPC attachment, traffic processing, and regional or inter-Region data transfer can incur charges.

## Run

Create `private-nat.tfvars` with the existing gateway ID and remote destinations:

```hcl
transit_gateway_id   = "tgw-0123456789abcdef0"
tgw_destination_cidrs = ["10.100.0.0/16", "10.200.0.0/16"]
```

```shell
terraform init
terraform validate
terraform plan -out=tfplan -var-file=private-nat.tfvars
terraform apply tfplan
terraform output private_nat_ips
terraform output route_counts
terraform destroy -var-file=private-nat.tfvars
```

`nat_public_ips` should remain empty and `route_counts.internet` should be zero; validate both forward and return routes in the TGW domain before sending production traffic through the translation path.
