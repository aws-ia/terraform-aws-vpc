<!-- BEGIN_TF_DOCS -->
# NAT Gateway Options

This example builds a VPC with public and private subnets in 2 availability zones.
It creates NAT GW in public subnet with either "none", "single\_az" or "all\_azs" option.
It creates routes from private subnets to NAT GW if `connect_to_public_natgw` is true otherwise no route is created.
It creates an internet gateway and appropriately routes subnet traffic from "0.0.0.0/0" to the IGW.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.27.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_nat_gw_vpc"></a> [nat\_gw\_vpc](#module\_nat\_gw\_vpc) | ../../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_nat_gateway_configuration"></a> [nat\_gateway\_configuration](#input\_nat\_gateway\_configuration) | all\_azs, single\_az, or none | `string` | n/a | yes |
| <a name="input_route_to_nw"></a> [route\_to\_nw](#input\_route\_to\_nw) | Should route to NATGW be created? | `bool` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nat_gateway_attributes_by_az"></a> [nat\_gateway\_attributes\_by\_az](#output\_nat\_gateway\_attributes\_by\_az) | Map of nat gateway resource attributes by AZ. |
| <a name="output_private_subnet_attributes_by_az"></a> [private\_subnet\_attributes\_by\_az](#output\_private\_subnet\_attributes\_by\_az) | Map of all private subnets containing their attributes. |
| <a name="output_public_subnet_attributes_by_az"></a> [public\_subnet\_attributes\_by\_az](#output\_public\_subnet\_attributes\_by\_az) | Map of all public subnets containing their attributes. |
| <a name="output_rt_attributes_by_type_by_az"></a> [rt\_attributes\_by\_type\_by\_az](#output\_rt\_attributes\_by\_type\_by\_az) | Map of route tables by type => az => route table attributes. |
<!-- END_TF_DOCS -->