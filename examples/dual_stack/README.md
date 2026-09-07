# Dual-stack and IPv6-native subnets

This example creates public and private dual-stack subnet groups plus a private IPv6-native subnet group across two Availability Zones. Use it to compare deterministic IPv4/IPv6 allocation, native IPv6 subnets, egress-only internet routing, and DNS64 behavior in one VPC.

## What this demonstrates

- A caller-owned `amazon-ipv6` key associates an Amazon-provided `/56` with the VPC.
- Matching `cidr_index` values assign stable IPv4 `/24` and IPv6 `/64` prefixes to the public and application groups.
- The `ipv6-native` group sets `native_only = true`, `auto_assign = true`, and has no IPv4 configuration.
- Public IPv6 traffic uses the Internet Gateway; private IPv6 traffic uses the egress-only Internet Gateway.
- DNS64 is enabled only for the IPv6-native group, while IPv4 egress for the application group uses Regional NAT.

## Relevant configuration

The complete configuration is in [`main.tf`](./main.tf). The differential subnet definitions are:

```hcl
subnets = {
  public = {
    role = "public"
    ipv4 = { netmask = 24, cidr_index = 0 }
    ipv6 = {
      secondary_cidr_key = "amazon-ipv6"
      auto_assign        = true
      cidr_index         = 0
    }
    routing = { internet_gateway = true }
  }

  application = {
    role = "private"
    ipv4 = { netmask = 24, cidr_index = 1 }
    ipv6 = {
      secondary_cidr_key = "amazon-ipv6"
      auto_assign        = true
      cidr_index         = 1
    }
    routing = {
      nat_gateway     = true
      egress_only_igw = true
    }
  }

  ipv6-native = {
    role = "private"
    ipv6 = {
      secondary_cidr_key = "amazon-ipv6"
      native_only        = true
      auto_assign        = true
      cidr_index         = 2
    }
    routing = {
      dns64           = true
      egress_only_igw = true
    }
  }
}

nat_gateway = {
  mode = "regional"
}
```

## Prerequisites and cost

- Terraform `>= 1.5` and AWS provider `>= 6.29`.
- AWS credentials with permissions to create a VPC, an Amazon-provided IPv6 CIDR association, subnets, route tables, an Internet Gateway, an egress-only Internet Gateway, and one Regional NAT Gateway.
- The account and selected Region must support IPv6-native subnets and DNS64.
- The default AZs are `us-east-1a` and `us-east-1b`; override `availability_zones` together if the account exposes different AZ names.
- **Cost:** the Regional NAT Gateway is billed across active AZs and incurs data-processing charges. Standard regional data-transfer and public IPv4 charges may also apply; Internet Gateways and egress-only Internet Gateways do not have hourly charges.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output subnet_ipv4_cidrs_by_group_by_az
terraform output subnet_ipv6_cidrs_by_group_by_az
terraform output nat_gateway_evidence
terraform destroy
```

After apply, `subnet_ipv4_cidrs_by_group_by_az["ipv6-native"]` should contain `null` for both AZs, while `subnet_ipv6_cidrs_by_group_by_az["ipv6-native"]` contains a `/64` per AZ. DNS64 synthesizes IPv6 answers, but reaching IPv4-only destinations still depends on an external NAT64 path; this example does not create NAT64 for the IPv6-native group.
