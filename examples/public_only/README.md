<!-- BEGIN_TF_DOCS -->
# Create VPC with public subnets

This example builds a VPC with public subnets in 3 availability zones. It creates an internet gateway and appropriately routes subnet traffic from "0.0.0.0/0" to the IGW.

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
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Map of subnet types with key/value az = cidr. |
<!-- END_TF_DOCS -->
