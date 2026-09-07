# Web application VPC

This example creates a three-AZ VPC with public, private application, and isolated database subnet groups. Use it for a conventional dual-stack web application that needs controlled internet egress, gateway endpoints, and CloudWatch flow logs.

## What this demonstrates

- An Amazon-provided IPv6 CIDR selected by the caller-owned `amazon-ipv6` key.
- Public, private, and isolated subnet roles with deterministic IPv4 allocation.
- Single-AZ NAT for development, plus egress-only IPv6 routing and DNS64 for application subnets.
- S3 and DynamoDB gateway endpoints associated through subnet routing declarations.
- A module-owned CloudWatch log group and IAM role for VPC Flow Logs.

## Relevant configuration

The complete configuration is in [`main.tf`](./main.tf). The application subnet and endpoint declarations are the scenario-specific portion:

```hcl
subnets = {
  app = {
    role = "private"
    ipv4 = { netmask = 22 }
    ipv6 = {
      secondary_cidr_key = "amazon-ipv6"
      auto_assign        = true
    }
    routing = {
      nat_gateway               = true
      egress_only_igw           = true
      dns64                     = true
      s3_gateway_endpoint       = true
      dynamodb_gateway_endpoint = true
    }
  }

  database = {
    role = "isolated"
    ipv4 = { netmask = 24 }
  }
}

nat_gateway = {
  mode         = "single_az"
  az           = "us-east-1a"
  subnet_group = "public"
}
```

## Prerequisites and cost

- Terraform `>= 1.5` and AWS provider `>= 6.29`.
- AWS credentials with permissions to create VPC networking, gateway endpoints, IAM resources, and CloudWatch Logs resources.
- Replace the account ID and DynamoDB table ARNs in the endpoint policy before using this configuration outside a demonstration account.
- The fixed NAT AZ must be available in the selected Region.
- **Cost:** one public NAT Gateway, one public IPv4 address, CloudWatch Logs ingestion and retention, data processing, and regional data transfer can incur charges.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output subnet_ids
terraform output gateway_endpoints
terraform destroy
```

The application group has resilient subnet placement but a single-AZ IPv4 egress dependency; choose `all_azs` or `regional` NAT for workloads that require a different availability model.
