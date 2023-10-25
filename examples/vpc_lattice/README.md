<!-- BEGIN_TF_DOCS -->
# Creating Amazon VPC Lattice Service Network VPC Assocation

This example shows how you can use this module to create a [VPC Lattice]() Service Network VPC association. The example creates:

* VPC Lattice Service Network.
* Security Group (allowing HTTP and HTTPS traffic from the local CIDR). Used to attach it to the VPC Lattice association
* The VPC module creates the following:
  * One set of subnets (*workload*)
  * VPC Lattice Service Network VPC association.

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
| [aws_security_group.security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpclattice_service_network.service_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_service_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region. | `string` | `"eu-west-1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_vpc_lattice_service_network_association"></a> [vpc\_lattice\_service\_network\_association](#output\_vpc\_lattice\_service\_network\_association) | VPC Lattice Service Network VPC association. |
<!-- END_TF_DOCS -->