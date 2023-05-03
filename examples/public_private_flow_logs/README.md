<!-- BEGIN_TF_DOCS -->
# Create VPC flow logs

This example builds a VPC with public and private subnets in 3 availability zones, creates a nat gateway in each AZ and appropriately routes from each private to the nat gateway. It creates an internet gateway and appropriately routes subnet traffic from "0.0.0.0/0" to the IGW. It creates encrypted VPC Flow Logs that are sent to cloud-watch and retained for 180 days.

At this point, only cloud-watch logs are support, pending: https://github.com/aws-ia/terraform-aws-vpc/issues/35

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.73.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.73.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | aws-ia/vpc/aws | >= 4.2.0 |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS Key ID | `string` | `null` | no |
| <a name="input_vpc_flow_logs"></a> [vpc\_flow\_logs](#input\_vpc\_flow\_logs) | Whether or not to create VPC flow logs and which type. Options: "cloudwatch", "s3", "none". | <pre>object({<br>    log_destination = optional(string)<br>    iam_role_arn    = optional(string)<br>    kms_key_id      = optional(string)<br><br>    log_destination_type = string<br>    retention_in_days    = optional(number)<br>    tags                 = optional(map(string))<br>    traffic_type         = optional(string)<br>    destination_options = optional(object({<br>      file_format                = optional(string)<br>      hive_compatible_partitions = optional(bool)<br>      per_hour_partition         = optional(bool)<br>    }))<br>  })</pre> | <pre>{<br>  "kms_key_id": null,<br>  "log_destination_type": "cloud-watch-logs",<br>  "retention_in_days": 180<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | Map of private subnet attributes grouped by az. |
| <a name="output_private_subnets_tags_length"></a> [private\_subnets\_tags\_length](#output\_private\_subnets\_tags\_length) | Count of private subnet tags for a single az. |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | Map of public subnet attributes grouped by az. |
| <a name="output_public_subnets_tags_length"></a> [public\_subnets\_tags\_length](#output\_public\_subnets\_tags\_length) | Count of public subnet tags for a single az. |
<!-- END_TF_DOCS -->