# Centralized interface endpoints and hybrid DNS

This example creates a two-AZ shared-services VPC, two spoke VPCs, and a Transit Gateway for centralized access to AWS service interface endpoints and hybrid DNS. Use it when workloads must resolve PrivateLink service names through Route 53 Profiles, resolve private application zones locally, and forward selected on-premises domains without Internet gateways or NAT gateways.

## What this demonstrates

- `endpoints` and `resolver` are `private` subnet groups with explicit TGW return routes; `tgw` is a separate `transit_gateway` group.
- Five interface endpoints keep Private DNS enabled and are associated by ARN with a Route 53 Profile that is associated with the hub and both spokes.
- Endpoint security groups allow TCP/443 only from the same `local.consumer_cidrs` used for hub return routing, and every endpoint has an explicit service-action policy.
- Inbound and outbound Resolver endpoints place one IP in each selected AZ. Their security groups allow inbound TCP/UDP 53 only from declared on-premises resolver CIDRs and outbound TCP/UDP 53 only to declared target IPs.
- Resolver rules, per-spoke rule associations, and RAM resource/principal associations remain separate resources with stable map keys.
- Caller-defined private hosted zones are associated directly with the hub and every spoke VPC.
- TGW attachments disable default route-table association and propagation; the example owns the replacement association and propagation resources explicitly.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). This excerpt shows the VPC contract boundary and the Route 53 Profiles path:

```hcl
subnets = {
  endpoints = {
    role = "private"
    ipv4 = {
      cidrs_by_az = {
        for index, az in var.availability_zones : az => cidrsubnet(local.hub_vpc_cidr, 8, index)
      }
    }
    routing = {
      internet_gateway = false
      transit_gateway_attachments = {
        dns-hub = local.consumer_cidrs
      }
    }
  }

  resolver = {
    role = "private"
    ipv4 = {
      cidrs_by_az = {
        for index, az in var.availability_zones : az => cidrsubnet(local.hub_vpc_cidr, 12, 256 + index)
      }
    }
    routing = {
      internet_gateway = false
      transit_gateway_attachments = {
        dns-hub = local.consumer_cidrs
      }
    }
  }

  tgw = {
    role = "transit_gateway"
    ipv4 = {
      cidrs_by_az = {
        for index, az in var.availability_zones : az => cidrsubnet(local.hub_vpc_cidr, 12, 256 + length(var.availability_zones) + index)
      }
    }
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value.service}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.vpc.subnet_ids_by_group["endpoints"]
  security_group_ids  = [aws_security_group.interface_endpoints.id]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DeclaredServiceActions"
      Effect    = "Allow"
      Principal = "*"
      Action    = sort(tolist(each.value.actions))
      Resource  = "*"
    }]
  })
}

resource "aws_route53profiles_resource_association" "interface_endpoints" {
  for_each = aws_vpc_endpoint.interface

  name         = "centralized-${each.key}"
  profile_id   = aws_route53profiles_profile.endpoints.id
  resource_arn = each.value.arn
}

resource "aws_route53profiles_association" "vpcs" {
  for_each = local.profile_vpcs

  name        = "centralized-${each.key}"
  profile_id  = aws_route53profiles_profile.endpoints.id
  resource_id = each.value
}
```

## Compatibility with classic private hosted zones

The classic pattern disables endpoint Private DNS and creates a private hosted zone plus aliases for every service namespace, as documented in the [AWS multi-VPC networking whitepaper](https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/centralized-access-to-vpc-private-endpoints.html). AWS recommends Route 53 Profiles for greenfield centralized endpoint DNS, so this example does not implement those service zones or aliases.

## Service-specific exceptions

Amazon ECR needs separate API and DKR endpoints, a wildcard DKR name in the classic hosted-zone design, and S3 access for image layers. S3 gateway endpoints remain local to each spoke and cannot be reached through TGW; private `execute-api` also requires API resource-policy and endpoint-association decisions, and broad Private DNS can hide public API default endpoints.

## Prerequisites and cost

- Terraform `>= 1.5` and AWS provider `>= 6.29, < 7.0`.
- AWS credentials with permissions for VPC, TGW, PrivateLink, Route 53 Profiles, Route 53 hosted zones, Route 53 Resolver, security groups, and RAM.
- The default `allow_external_principals = false` requires AWS RAM sharing with AWS Organizations to be enabled for the account.
- At least two distinct AZs. Resolver creates one inbound and one outbound IP/ENI per AZ; every interface endpoint creates one endpoint ENI per AZ.
- `consumer_cidrs` must include every remote HTTPS consumer and the return prefixes reachable through the TGW. They must not overlap `10.250.0.0/16`.
- On-premises routing must connect the TGW to the declared DNS resolver network, and on-premises DNS must conditionally forward AWS/private domains to both inbound endpoint IPs.
- Sandbox apply verification confirms that Route 53 Profiles accepts an interface VPC endpoint ARN in `aws_route53profiles_resource_association.resource_arn`; both the endpoint resource association and the Profile-to-VPC association reached `COMPLETE`.
- **Cost:** the TGW and three VPC attachments, ten interface endpoint ENIs, four Resolver ENIs, DNS queries, RAM sharing, data processing, and cross-AZ or hybrid transfer can incur charges. There are no Internet Gateway or NAT Gateway charges in this topology.

Check current Service Quotas before applying. Resolver endpoints default to four per account/Region and six IPs per endpoint; interface endpoints and Route 53 Profile associations also have regional quotas.

Route 53 Profile association waiters can run for about 97 seconds; if the provider reports `Plugin did not respond` while AWS completes asynchronously, retrying the same operation converges.

## Run

Create `centralized-endpoints-dns.tfvars` with real network values when replacing the documentation-only on-premises addresses:

```hcl
consumer_cidrs     = ["172.16.0.0/16"]
on_prem_dns_cidrs = ["172.16.10.0/24"]
forwarding_rules = {
  corporate = {
    domain_name = "corp.example.com."
    target_ips = {
      primary   = { ip = "172.16.10.53", port = 53 }
      secondary = { ip = "172.16.10.54", port = 53 }
    }
  }
}
ram_principals = ["123456789012"]
```

```shell
terraform init
terraform validate
terraform plan -out=tfplan -var-file=centralized-endpoints-dns.tfvars
terraform apply tfplan
terraform output profile_evidence
terraform output resolver_evidence
terraform output connectivity_evidence
terraform destroy -var-file=centralized-endpoints-dns.tfvars
```

After apply, verify from each spoke that the standard SSM, SSM Messages, EC2 Messages, CloudWatch Logs, and regional STS names resolve to the hub endpoint IPs and that HTTPS reaches them without Internet egress. Verify `onprem.example.com` through the outbound rule, query the private zone through VPC+2, and configure on-premises conditional forwarding to both inbound Resolver addresses before testing the reverse path.
