<!-- BEGIN_TF_DOCS -->
# VPC module - Example: AWS Transit Gateway connectivity

This example shows how you can use this module to crete a AWS Transit Gateway VPC attachment. This examples creates the following:

* AWS Transit Gateway.
* IPv4 managed prefix list with two entries.
* The VPC module creates the following:
  * Three sets of subnets (*private\_ipv4*, *private\_dualstack*, and *transit\_gateway*)
  * Transit Gateway VPC attachment.
  * Routing to Transit Gateway attachment:
    * IPv4 routes from *private\_ipv4*, and *private\_dualstack*.
    * IPv6 routes from *private\_dualstack*.

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

## Resources

| Name | Type |
|------|------|
| [aws_ec2_managed_prefix_list.prefix_list](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_managed_prefix_list) | resource |
| [aws_ec2_transit_gateway.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_availability_zones.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region. | `string` | `"eu-west-1"` | no |
| <a name="input_prefixes"></a> [prefixes](#input\_prefixes) | IPv4 prefixes. | `map(string)` | <pre>{<br/>  "internal": "192.168.0.0/16",<br/>  "primary": "10.0.0.0/8"<br/>}</pre> | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->