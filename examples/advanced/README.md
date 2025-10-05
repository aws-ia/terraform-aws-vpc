<!-- BEGIN_TF_DOCS -->
# VPC module - Example: Advanced VPC

This example builds an Amazon VPC with advanced functionality:

* IPv4-only VPC.
    * NAT gateway configured only in 1 AZ.
* 4 VPC subnets - 1 public (dual-stack), 3 private (IPv4-only, dual-stack, and IPv6-only)
    * Subnet CIDRs calculated to optimize IPv4 adress space (variable `optimize_subnet_cidr_ranges`)
* Flow logs enabled (destination Amazon S3)
* Secondary IPv4 CIDR block.
* Routing - egress traffic through NAT gateways in private subnets (check also the configuration on NAT gateway routing when building the subnets with secondary CIDR block).

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_secondary_cidr_block"></a> [secondary\_cidr\_block](#module\_secondary\_cidr\_block) | ../.. | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region. | `string` | `"eu-west-1"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->