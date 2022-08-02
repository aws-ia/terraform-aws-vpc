<!-- BEGIN_TF_DOCS -->
# Create VPC flow logs

This example builds a VPC with public and private subnets in 3 availability zones, creates a nat gateway in each AZ and appropriately routes from each private to the nat gateway. It creates an internet gateway and appropriately routes subnet traffic from "0.0.0.0/0" to the IGW. It creates encrypted VPC Flow Logs that are sent to cloud-watch and retained for 180 days.

At this point, only cloud-watch logs are support, pending: https://github.com/aws-ia/terraform-aws-vpc/issues/35

## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | aws-ia/vpc/aws | >= 1.0.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS Key ID | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Map of subnet types with key/value az = cidr. |
<!-- END_TF_DOCS -->