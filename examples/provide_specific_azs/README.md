<!-- BEGIN_TF_DOCS -->
# Deploy VPC subnets to a specific set of Availability Zones

This example shows how you can use this module to deploy a VPC defining a list of specific Availability Zones where subnets should be deployed. This example creates the following:

* VPC with IPv4 CIDR block named "specific-azs"
* Private subnets deployed in each of the Availability Zones defined in the input variable `azs` with the name prefix "vpc-specific-azs-private" and a /18 netmask

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
| <a name="module_vpc_specific_azs"></a> [vpc\_specific\_azs](#module\_vpc\_specific\_azs) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region. | `string` | `"us-east-1"` | no |
| <a name="input_azs"></a> [azs](#input\_azs) | A list of AZs to use. e.g. `azs = ["us-east-1a","us-east-1c"]` Incompatible with `az_count` | `list(string)` | <pre>[<br/>  "us-east-1a",<br/>  "us-east-1c"<br/>]</pre> | no |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | IPv4 CIDR range to assign to VPC if creating VPC or to associate as a secondary IPv6 CIDR. Overridden by var.vpc\_id output from data.aws\_vpc. | `string` | `"10.0.0.0/16"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->