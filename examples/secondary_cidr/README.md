<!-- BEGIN_TF_DOCS -->
# Adding secondary CIDRs to pre-existing VPCs

This example shows how you can use this module to apply a secondary CIDR to a pre-existing VPC.

Note: If using IPAM, you can only build 1 secondary CIDR at a time. One method to do that is to use `-target`. Using the example you would uncomment the "vpc" and "ipam\_base\_for\_example\_only" modules then:

1. terraform init
1. terraform apply -target module.vpc -target module.ipam\_base\_for\_example\_only
1. terraform apply -target module.secondary

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_secondary"></a> [secondary](#module\_secondary) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_nat_gateway.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/nat_gateway) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | az count | `number` | `1` | no |
| <a name="input_natgw_id_per_az"></a> [natgw\_id\_per\_az](#input\_natgw\_id\_per\_az) | use the modules natgw\_id\_per\_az | `map(map(string))` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | vpc id to create secondary cidr on | `string` | `null` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->