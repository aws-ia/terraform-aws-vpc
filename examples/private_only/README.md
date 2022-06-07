<!-- BEGIN_TF_DOCS -->
# Create VPC with private subnets

This example builds a VPC with private subnets in 3 availability zones

## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | aws-ia/vpc/aws | >= 1.0.0 |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private_subnet_attributes"></a> [private\_subnet\_attributes](#output\_private\_subnet\_attributes) | n/a |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Map of subnet types with key/value az = cidr. |
<!-- END_TF_DOCS -->