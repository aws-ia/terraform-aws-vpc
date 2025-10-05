<!-- BEGIN_TF_DOCS -->
# VPC module - Example: Basic VPC

This example builds an Amazon VPC with basic functionality:

* Dual-stack VPC (IPv4 & IPv6)
    * Egress-only Internet gateway configured.
* 4 VPC subnets - 1 public (dual-stack), 3 private (IPv4-only, dual-stack, and IPv6-only)
    * NAT gateways placed in all the public subnets.
* Flow logs enabled (destination Amazon CloudWatch)
* Routing:
    * IPv4 egress enabled in public subnets (through Internet gateway) and private subnets (through NAT gateways)
    * IPv6 egress enabled in private subnets (through Egress-only Internet gateway)

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