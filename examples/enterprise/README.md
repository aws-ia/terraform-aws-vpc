# Enterprise VPC with shared-services addressing

This example creates a three-AZ enterprise VPC with explicit IPv4 ranges, dual-stack application subnets, tier-specific Network ACLs, S3 and DynamoDB gateway endpoints, Regional NAT, flow logs, and a VPC Lattice association. Use it when address ownership, stateless tier boundaries, private AWS service access, service-network connectivity, and public egress must be declared together.

## What this demonstrates

- Explicit CIDRs preserve subnet identity across the selected Availability Zones.
- A named secondary IPv4 association isolates the endpoint address space from the primary VPC range.
- Public, application, data, and endpoint tiers each own a typed Network ACL with explicit stateless return paths.
- Application, data, and endpoint route tables use S3 and DynamoDB gateway endpoints; application subnets retain dual-stack egress through Regional NAT and an egress-only Internet Gateway.
- A module-owned flow-log destination and a caller-created VPC Lattice service network are composed in one configuration.

## Relevant configuration

The complete configuration is in [`main.tf`](./main.tf). The tier controls and private service routes are the distinguishing declarations:

```hcl
subnets = {
  endpoints = {
    role = "isolated"
    ipv4 = {
      cidrs_by_az = {
        "eu-west-1a" = "100.64.0.0/26"
        "eu-west-1b" = "100.64.0.64/26"
        "eu-west-1c" = "100.64.0.128/26"
      }
      secondary_cidr_key = "shared-services"
    }
    routing = {
      s3_gateway_endpoint       = true
      dynamodb_gateway_endpoint = true
    }
    network_acl = {
      ingress = {
        "100" = { protocol = "tcp", action = "allow", cidr_block = "10.0.0.0/16", from_port = 443, to_port = 443 }
        "110" = { protocol = "tcp", action = "allow", cidr_block = "100.64.0.0/20", from_port = 443, to_port = 443 }
      }
      egress = {
        "100" = { protocol = "tcp", action = "allow", cidr_block = "10.0.0.0/16", from_port = 1024, to_port = 65535 }
        "110" = { protocol = "tcp", action = "allow", cidr_block = "100.64.0.0/20", from_port = 1024, to_port = 65535 }
      }
    }
  }
}

gateway_endpoints = {
  s3       = { service = "s3" }
  dynamodb = { service = "dynamodb" }
}

nat_gateway = {
  mode = "regional"
}
```

## Prerequisites and cost

- Terraform `>= 1.5` and AWS provider `>= 6.29`.
- AWS credentials with permissions for VPC networking, gateway endpoints, Network ACLs, CloudWatch Logs, IAM, and VPC Lattice service networks and associations.
- The explicit `eu-west-1a`, `eu-west-1b`, and `eu-west-1c` names and every `cidrs_by_az` key must be changed together when selecting another Region or AZ set.
- Review every NACL CIDR, protocol, port, stateless reverse path, endpoint policy, and Lattice authorization model against organizational controls before deployment.
- **Cost:** one Regional NAT Gateway billed across three active AZs, public IPv4 addresses, CloudWatch Logs ingestion and retention, traffic processing, regional transfer, and VPC Lattice usage can incur charges. S3 and DynamoDB gateway endpoints have no hourly endpoint charge.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output subnet_cidrs
terraform output network_acl_controls
terraform output gateway_endpoints
terraform output nat_gateway_evidence
terraform output lattice_association_id
terraform destroy
```

The isolated subnet roles create no default internet or transit routes. Gateway endpoint policies, security groups on communicating resources, and the tier-specific NACL rules must all authorize the intended application and data flows.
