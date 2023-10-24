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
| <a name="module_ipam_base_for_example_only"></a> [ipam\_base\_for\_example\_only](#module\_ipam\_base\_for\_example\_only) | ../../test/hcl_fixtures/ipam_base | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../.. | n/a |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | Map of private subnet attributes grouped by az. |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | Map of public subnet attributes grouped by az. |
<!-- END_TF_DOCS -->