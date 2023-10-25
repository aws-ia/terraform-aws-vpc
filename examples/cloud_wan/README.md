<!-- BEGIN_TF_DOCS -->
# Creating AWS Cloud WAN's VPC attachment

This example shows how you can use this module with `core_network` subnets, and AWS Cloud WAN's VPC attachment. This examples creates the following:

* Global Network and Core Network.
* Core Network's policy (in `cwan_policy.tf`), creating two segments (prod and nonprod) in two AWS Regions (*us-east-1* and *eu-west-1*). The *prod* segments needs acceptance for the attachments.
* The VPC module creates the following (in two AWS Regions):
  * Two sets of subnets (workloads and core\_network)
  * Cloud WAN's VPC attachment - with attachment acceptance for the VPC to associate to the *prod* segment.
  * Routing to Core Network (0.0.0.0/0 & ::/0) in workload subnets.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.22.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.22.0 |
| <a name="provider_aws.awsnvirginia"></a> [aws.awsnvirginia](#provider\_aws.awsnvirginia) | >= 5.22.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ireland_vpc"></a> [ireland\_vpc](#module\_ireland\_vpc) | ../.. | n/a |
| <a name="module_nvirginia_vpc"></a> [nvirginia\_vpc](#module\_nvirginia\_vpc) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_core_network) | resource |
| [aws_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_global_network) | resource |
| [aws_networkmanager_core_network_policy_document.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/networkmanager_core_network_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_wan_regions"></a> [cloud\_wan\_regions](#input\_cloud\_wan\_regions) | AWS Regions to create in Cloud WAN's core network. | <pre>object({<br>    nvirginia = string<br>    ireland   = string<br>  })</pre> | <pre>{<br>  "ireland": "eu-west-1",<br>  "nvirginia": "us-east-1"<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_core_network"></a> [core\_network](#output\_core\_network) | Core Network ID. |
| <a name="output_core_network_vpc_attachments"></a> [core\_network\_vpc\_attachments](#output\_core\_network\_vpc\_attachments) | Core Network VPC attachments. |
| <a name="output_global_network"></a> [global\_network](#output\_global\_network) | Global Network ID. |
| <a name="output_vpcs"></a> [vpcs](#output\_vpcs) | VPCs created. |
<!-- END_TF_DOCS -->