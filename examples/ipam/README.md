<!-- BEGIN_TF_DOCS -->
# Create VPC with a CIDR from AWS IPAM

This example builds a VPC with a CIDR block from AWS IPAM. It builds public and private subnets in 3 availability zones, creates a nat gateway in each AZ and appropriately routes from each private to the nat gateway.

## Requirements

No requirements.

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
| <a name="input_ipam_pool_id"></a> [ipam\_pool\_id](#input\_ipam\_pool\_id) | pool id to request CIDR from. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Map of subnet types with key/value az = cidr. |
<!-- END_TF_DOCS -->