<!-- BEGIN_TF_DOCS -->
# Creating Dual-Stack and IPv6-only subnets

This example shows how you can create dual-stack and IPv6-only subnets in your Amazon VPC. This example creates the following:

* VPC with IPv4 CIDR block and Amazon-generated IPv6 CIDR block.
* Internet gateway and Egress-only Internet gateway.
* 4 subnet types:
  * Public subnet (dual-stack) with NAT gateways in all the Availability Zones used.
  * IPv4-only private subnet, with default routes (0.0.0.0/0) via the NAT gateways.
  * Dual-stack private subnet, with IPv4 default route (0.0.0.0/0) via the NAT gateways and IPv6 default route (::/0) via the Egress-only Internet gateway.
  * IPv6-only private subnet, with IPv6 default route (::/0) via the Egress-only Internet gateway.

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
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region. | `string` | `"eu-west-2"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->