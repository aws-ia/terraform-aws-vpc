<!-- BEGIN_TF_DOCS -->
# AWS VPC Module

This module can be used to deploy a pragmatic VPC with various subnets types in # AZs. Common deployment examples can be found in [examples/](https://github.com/aws-ia/terraform-aws-vpc/tree/main/examples). Subnet CIDRs can be explicitly set via list of string argument `cidrs` or set via a number `netmask` argument.

## Usage

The example below builds a VPC with public and private subnets in 3 AZs. Each subnet calulates a CIDR based on the `netmask` argument passed. The public subnets build nat gateways in each AZ but optionally can be switched to `single_az`.

```hcl
module "vpc" {
  source   = "aws-ia/vpc/aws"
  version = ">= 1.0.0"

  name           = "multi-az-vpc"
  cidr_block = "10.0.0.0/20"
  az_count       = 3

  subnets = {
    public = {
      name_prefix               = "my-public" # omit to prefix with "public"
      netmask                   = 24
      nat_gateway_configuration = "all_azs" # options: "single_az", "none"
    }

    private = {
      # omitting name_prefix defaults value to "private"
      # name_prefix  = "private"
      netmask      = 24
      route_to_nat = true
    }
  }

  vpc_flow_logs = {
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
  }
}
```

## Updating a VPC with new or removed subnets

If using `netmask` to calculate subnets and you wish to either add or remove subnets (ex: adding / removing an AZ), you may have to change from using `netmask` for some subnets and set to explicit instead. Private subnets are always calculated before public.

When changing to explicit cidrs, subnets are always ordered by AZ. `0` -> a, `1` -> b, etc.

Example: Changing from 2 azs to 3

Before:
```hcl
cidr_block = "10.0.0.0/16"
az_count = 2

subnets = {
  public = {
   netmask = 24
  }

  private = {
   netmask = 24
  }
}
```

After:
```hcl
cidr_block = "10.0.0.0/16"
az_count = 3

subnets = {
  public = {
   cidrs = ["10.0.0.0/24", "10.0.1.0/24", "10.0.4.0/24"]
  }

  private = {
   cidrs = ["10.0.2.0/24", "10.0.3.0/24", "10.0.5.0/24"]
  }
}
```

The above example will cause only creating 2 new subnets in az `c` of the region being used.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.15.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.73.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 0.15.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.73.0 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | >= 0.15.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_calculate_subnets"></a> [calculate\_subnets](#module\_calculate\_subnets) | ./modules/calculate_subnets | n/a |
| <a name="module_flow_logs"></a> [flow\_logs](#module\_flow\_logs) | ./modules/flow_logs | n/a |
| <a name="module_tags"></a> [tags](#module\_tags) | aws-ia/label/aws | 0.0.5 |

## Resources

| Name | Type |
|------|------|
| [aws_ec2_transit_gateway_route_table_association.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_vpc_attachment.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_to_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_to_igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_ipv4_cidr_block_association.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipv4_cidr_block_association) | resource |
| [awscc_ec2_route_table.private](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_route_table) | resource |
| [awscc_ec2_route_table.public](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_route_table) | resource |
| [awscc_ec2_subnet_route_table_association.private](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet_route_table_association) | resource |
| [awscc_ec2_subnet_route_table_association.public](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet_route_table_association) | resource |
| [aws_availability_zones.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_vpc_ipam_preview_next_cidr.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc_ipam_preview_next_cidr) | data source |
| [awscc_ec2_vpc.main](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/data-sources/ec2_vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Searches region for # of AZs to use and takes a slice based on count. Assume slice is sorted a-z. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name to give VPC. Note: does not effect subnet names, which get assigned name based on name\_prefix. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Configuration of subnets to build in VPC. Valid key restriction information found in variables.tf. | `any` | n/a | yes |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | CIDR range to assign to VPC if creating VPC or to associte as a secondary CIDR. Overridden by var.vpc\_id output from data.aws\_vpc. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_vpc_enable_dns_hostnames"></a> [vpc\_enable\_dns\_hostnames](#input\_vpc\_enable\_dns\_hostnames) | Indicates whether the instances launched in the VPC get DNS hostnames. If enabled, instances in the VPC get DNS hostnames; otherwise, they do not. Disabled by default for nondefault VPCs. | `bool` | `true` | no |
| <a name="input_vpc_enable_dns_support"></a> [vpc\_enable\_dns\_support](#input\_vpc\_enable\_dns\_support) | Indicates whether the DNS resolution is supported for the VPC. If enabled, queries to the Amazon provided DNS server at the 169.254.169.253 IP address, or the reserved IP address at the base of the VPC network range "plus two" succeed. If disabled, the Amazon provided DNS service in the VPC that resolves public DNS hostnames to IP addresses is not enabled. Enabled by default. | `bool` | `true` | no |
| <a name="input_vpc_flow_logs"></a> [vpc\_flow\_logs](#input\_vpc\_flow\_logs) | Whether or not to create VPC flow logs and which type. Options: "cloudwatch", "s3", "none". By default creates flow logs to `cloudwatch`. Variable overrides null value types for some keys, defined in defaults.tf. | <pre>object({<br>    log_destination = optional(string)<br>    iam_role_arn    = optional(string)<br>    kms_key_id      = optional(string)<br><br>    log_destination_type = string<br>    retention_in_days    = optional(number)<br>    tags                 = optional(map(string))<br>    traffic_type         = optional(string)<br>    destination_options = optional(object({<br>      file_format                = optional(string)<br>      hive_compatible_partitions = optional(bool)<br>      per_hour_partition         = optional(bool)<br>    }))<br>  })</pre> | <pre>{<br>  "log_destination_type": "none"<br>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to use if not creating VPC. | `string` | `null` | no |
| <a name="input_vpc_instance_tenancy"></a> [vpc\_instance\_tenancy](#input\_vpc\_instance\_tenancy) | The allowed tenancy of instances launched into the VPC. | `string` | `"default"` | no |
| <a name="input_vpc_ipv4_ipam_pool_id"></a> [vpc\_ipv4\_ipam\_pool\_id](#input\_vpc\_ipv4\_ipam\_pool\_id) | Set to use IPAM to get CIDR block. | `string` | `null` | no |
| <a name="input_vpc_ipv4_netmask_length"></a> [vpc\_ipv4\_netmask\_length](#input\_vpc\_ipv4\_netmask\_length) | Set to use IPAM to get CIDR block using a specified netmask. Must be set with var.vpc\_ipv4\_ipam\_pool\_id. | `string` | `null` | no |
| <a name="input_vpc_secondary_cidr"></a> [vpc\_secondary\_cidr](#input\_vpc\_secondary\_cidr) | If `true` the module will create a `aws_vpc_ipv4_cidr_block_association` and subnets for that secondary cidr. If using IPAM for both primary and secondary CIDRs, you may only call this module serially (aka using `-target`, etc). | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private_subnet_attributes_by_az"></a> [private\_subnet\_attributes\_by\_az](#output\_private\_subnet\_attributes\_by\_az) | Map of all private subnets containing their attributes. |
| <a name="output_public_subnet_attributes_by_az"></a> [public\_subnet\_attributes\_by\_az](#output\_public\_subnet\_attributes\_by\_az) | Map of all public subnets containing their attributes. |
| <a name="output_route_table_by_subnet_type"></a> [route\_table\_by\_subnet\_type](#output\_route\_table\_by\_subnet\_type) | Map of route tables by type => az => route table attributes. Example usage: module.vpc.route\_table\_by\_subnet\_type.private.id |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Map of subnets grouped by type with child map { az = cidr }. |
| <a name="output_tgw_subnet_attributes_by_az"></a> [tgw\_subnet\_attributes\_by\_az](#output\_tgw\_subnet\_attributes\_by\_az) | Map of all transit gateway subnets containing their attributes. |
| <a name="output_transit_gateway_attachment_id"></a> [transit\_gateway\_attachment\_id](#output\_transit\_gateway\_attachment\_id) | Transit gateway attachment id. |
| <a name="output_vpc_attributes"></a> [vpc\_attributes](#output\_vpc\_attributes) | VPC resource attributes. Full output of aws\_vpc. |
<!-- END_TF_DOCS -->