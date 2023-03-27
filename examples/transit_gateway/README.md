<!-- BEGIN_TF_DOCS -->
# Creating AWS Transit Gateway VPC attachment

This example shows how you can use this module with `transit_gateway` subnets, and AWS Transit Gateway VPC attachment. This examples creates the following:

* AWS Transit Gateway.
* The VPC module creates the following:
  * Four sets of subnets (*public*, *private\_with\_egress*, *truly\_private*, and *transit\_gateway*)
  * Transit Gateway VPC attachment.
  * Routing to Transit Gateway attachment from *public* and *private\_with\_egress* subnets.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_tgw_base_for_example_only"></a> [tgw\_base\_for\_example\_only](#module\_tgw\_base\_for\_example\_only) | ../../test/hcl_fixtures/transit_gateway_base | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | aws-ia/vpc/aws | >= 4.0.0 |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private_subnets_tags_length"></a> [private\_subnets\_tags\_length](#output\_private\_subnets\_tags\_length) | Count of private subnet tags for a single az. |
| <a name="output_tgw_subnets_tags_length"></a> [tgw\_subnets\_tags\_length](#output\_tgw\_subnets\_tags\_length) | Count of tgw subnet tags for a single az. |
<!-- END_TF_DOCS -->