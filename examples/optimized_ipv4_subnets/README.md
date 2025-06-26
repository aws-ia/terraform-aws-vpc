<!-- BEGIN_TF_DOCS -->
# Creating subnets with sorted CIDR ranges

This example shows how you can use this module to efficiently use the VPC CIDR range. Before calculating CIDR ranges, subnets are sorted from largest to smallest.

* The VPC module creates the following:
  * Four sets of subnets (*public*, *private*, *database*, and *infrastructure*)

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | aws-ia/vpc/aws | ~> 4.4 |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region to create resources in. | `string` | `"eu-west-2"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | VPC cidr range | `string` | `"10.0.0.0/22"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private_subnets_tags_length"></a> [private\_subnets\_tags\_length](#output\_private\_subnets\_tags\_length) | Count of private subnet tags for a single az. |
<!-- END_TF_DOCS -->