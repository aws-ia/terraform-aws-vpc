<!-- BEGIN_TF_DOCS -->
# Create VPC flow logs

This example builds a VPC with public and private subnets in 3 availability zones, creates a nat gateway in each AZ and appropriately routes from each private to the nat gateway. It creates an internet gateway and appropriately routes subnet traffic from "0.0.0.0/0" to the IGW. It creates encrypted VPC Flow Logs that are sent to cloud-watch and retained for 180 days.

At this point, only cloud-watch logs are support, pending: https://github.com/aws-ia/terraform-aws-vpc/issues/35

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../.. | n/a |
| <a name="module_vpc2"></a> [vpc2](#module\_vpc2) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region. | `string` | `"eu-west-1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_log_name"></a> [log\_name](#output\_log\_name) | Name of the flow log. |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | Map of private subnet attributes grouped by az. |
| <a name="output_private_subnets_tags_length"></a> [private\_subnets\_tags\_length](#output\_private\_subnets\_tags\_length) | Count of private subnet tags for a single az. |
| <a name="output_public_subnets_tags_length"></a> [public\_subnets\_tags\_length](#output\_public\_subnets\_tags\_length) | Count of public subnet tags for a single az. |
| <a name="output_vpc_attributes"></a> [vpc\_attributes](#output\_vpc\_attributes) | Output of all VPC attributes. |
<!-- END_TF_DOCS -->