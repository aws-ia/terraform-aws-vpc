<!-- BEGIN_TF_DOCS -->
# AWS VPC Module

This module can be used to deploy a pragmatic VPC with various subnets types in # AZs. Common deployment examples can be found in [examples/](https://github.com/aws-ia/terraform-aws-vpc/tree/main/examples). Subnet CIDRs can be explicitly set via list of string argument `cidrs` or set via a number `netmask` argument.

## Usage

The example below builds a VPC with public and private subnets in 3 AZs. Each subnet calulates a CIDR based on the `netmask` argument passed. The public subnets build nat gateways in each AZ but optionally can be switched to `single_az`.

```hcl
module "vpc" {
  source   = "aws-ia/vpc/aws"
  version = ">= 1.0.0"

  name       = "multi-az-vpc"
  cidr_block = "10.0.0.0/20"
  az_count   = 3

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

## Reserved Subnet Key Names

There are 2 reserved keys for subnet key names in var.subnets corresponding to types "public" and "transit\_gateway". Other custom subnet key names are valid are and those subnets will be private subnets.

```terraform
subnets = {
  public = {
    name_prefix               = "my-public" # omit to prefix with "public"
    netmask                   = 24
    nat_gateway_configuration = "all_azs" # options: "single_az", "none"
  }

  # naming private is not required, can use any key
  private = {
    # omitting name_prefix defaults value to "private"
    # name_prefix  = "private"
    netmask      = 24
    route_to_nat = true
  }

  # can be any valid key name
  privatetwo = {
    # omitting name_prefix defaults value to "private"
    # name_prefix  = "private"
    netmask      = 24
    route_to_nat = false
    route_to_transit_gateway = ["10.0.0.0/8"]
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

## Output manipulation

The outputs in this module attempt to align to a methodology of outputting resource attributes in a reasonable collection. The benefit of this is that, most likely, attributes you want access to are already present without having to create new `output {}` for each possible attribute. The [potential] downside is that you will have to extract it yourself using HCL logic. Below are some common examples:

### Extracting subnet IDs for private subnets

Example Configuration:
```terraform
module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 1.0.0"

  name       = "multi-az-vpc"
  cidr_block = "10.0.0.0/20"
  az_count   = 3

  subnets = {
    private = { netmask = 24 }
  }
}
```

Extracting subnet\_ids to a list (using `terraform console` for example output):
```terraform
> [ for _, value in module.vpc.private_subnet_attributes_by_az: value.id]
[
  "subnet-04a86315c4839b519",
  "subnet-02a7249c8652a7136",
  "subnet-09af79b5329b3681f",
]
```

Alternatively, since these are maps, you can use key in another resource `for_each` loop. The benefit here is that your dependent resource will have keys that match the AZ the subnet is in:

```terraform
resource "aws_route53recoveryreadiness_cell" "cell_per_az" {
  for_each = module.vpc.private_subnet_attributes_by_az

  cell_name = "${each.key}-failover-cell-for-subnet-${each.value.id}"
}
...
```

Terraform Plan:

```shell
# aws_route53recoveryreadiness_cell.cell_per_az["us-east-1a"] will be created
+ resource "aws_route53recoveryreadiness_cell" "cell_per_az" {
    + cell_name               = "us-east-1a-failover-cell-for-subnet-subnet-070696086c5864da1"
    ...
  }

# aws_route53recoveryreadiness_cell.cell_per_az["us-east-1b"] will be created
...
```

## Moved Resources

While upgrading this module to allow for multiple private subnets, we had to adjust how we name private subnet related resources. To ease user pain we created the moved.tf file which creates corresponding entries for each private resource. However, we were unable to update `aws_route.private_to_tgw` because we used the user provided CIDR in the key. If you see a `CREATE/DELETE` for these resources you can either allow TF to force create the new routes (momentary blip in traffic) or you can manully update the name, example below:

If you see a message in your plan like this:

> module.vpc.aws\_route.private\_to\_tgw["us-east-1a:10.0.0.0/8"] -> ["private/us-east-1a"]

Resolve with this command per AZ
```shell
terraform state mv 'module.vpc.aws_route.private_to_tgw["us-east-1a:10.0.0.0/8"]' 'module.vpc.aws_route.private_to_tgw["private/us-east-1a"]'
```

If for some reason, you want to adusted the moved.tf file to accomplish the state mv commands for you, or move other resources, the python used to generate moved.tf can be found in [moved\_block\_rendering/](https://github.com/aws-ia/terraform-aws-vpc/tree/main/moved_block_rendering)

## Deprecation Notices and Breaking Changes

Overtime we will update this module to support new features. If a breaking change is introduced we will do a major update via semver. We're currently tracking targeted changes for v2.x [in this issue](https://github.com/aws-ia/terraform-aws-vpc/issues/62). There is currently no date for a 2.x release.

## Contributing

Please see our [developer documentation](https://github.com/aws-ia/terraform-aws-vpc/blob/main/contributing.md) for guidance on contributing to this module

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
| [aws_route.public_to_tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.tgw_to_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_ipv4_cidr_block_association.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipv4_cidr_block_association) | resource |
| [awscc_ec2_route_table.private](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_route_table) | resource |
| [awscc_ec2_route_table.public](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_route_table) | resource |
| [awscc_ec2_route_table.tgw](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_route_table) | resource |
| [awscc_ec2_subnet_route_table_association.private](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet_route_table_association) | resource |
| [awscc_ec2_subnet_route_table_association.public](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet_route_table_association) | resource |
| [awscc_ec2_subnet_route_table_association.tgw](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet_route_table_association) | resource |
| [aws_availability_zones.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_vpc_ipam_preview_next_cidr.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc_ipam_preview_next_cidr) | data source |
| [awscc_ec2_vpc.main](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/data-sources/ec2_vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Searches region for # of AZs to use and takes a slice based on count. Assume slice is sorted a-z. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name to give VPC. Note: does not effect subnet names, which get assigned name based on name\_prefix. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Configuration of subnets to build in VPC. 1 Subnet per AZ is created. Subnet types are defined as maps with the available keys: "private", "public", "transit\_gateway". Each Subnet type offers its own set of available arguments detailed below.<br><br>**Attributes shared across subnet types:**<br>- `cidrs`       = (Optional\|list(string)) **Cannot set if `netmask` is set.** List of CIDRs to set to subnets. Count of CIDRs defined must match quatity of azs in `az_count`.<br>- `netmask`     = (Optional\|Int) Netmask of the `var.cidr_block` to calculate for each subnet. **Cannot set if `cidrs` is set.**<br>- `name_prefix` = (Optional\|String) A string prefix to use for the name of your subnet and associated resources. Subnet type key name is used if omitted (aka private, public, transit\_gateway). Example `name_prefix = "private"` for `var.subnets.private` is redundant.<br>- `tags`        = (Optional\|map(string)) Tags to set on the subnet and associated resources.<br><br>**private subnet type options:**<br>- All shared keys above<br>- `route_to_nat`             = (Optional\|bool) Determines if routes to NAT Gateways should be created. Default = false. Must also set `var.subnets.public.nat_gateway_configuration`.<br>- `route_to_transit_gateway` = (Optional\|list(string)) Optionally create routes from private subnets to transit gateway subnets.<br><br>**public subnet type options:**<br>- All shared keys above<br>- `nat_gateway_configuration` = (Optional\|string) Determines if NAT Gateways should be created and in how many AZs. Valid values = `"none"`, `"single_az"`, `"all_azs"`. Default = "none". Must also set `var.subnets.private.route_to_nat = true`.<br>- `route_to_transit_gateway`  = (Optional\|list(string)) Optionally create routes from private subnets to transit gateway subnets.<br><br>**transit\_gateway subnet type options:**<br>- All shared keys above<br>- `route_to_nat`                                    = (Optional\|bool) Determines if routes to NAT Gateways should be created. Default = false. Must also set `var.subnets.public.nat_gateway_configuration`.<br>- `transit_gateway_id`                              = (Required\|string) Transit gateway to attach VPC to.<br>- `transit_gateway_default_route_table_association` = (Optional\|bool) Boolean whether the VPC Attachment should be associated with the EC2 Transit Gateway association default route table. This cannot be configured or perform drift detection with Resource Access Manager shared EC2 Transit Gateways.<br>- `transit_gateway_default_route_table_propagation` = (Optional\|bool) Boolean whether the VPC Attachment should propagate routes with the EC2 Transit Gateway propagation default route table. This cannot be configured or perform drift detection with Resource Access Manager shared EC2 Transit Gateways.<br>- `transit_gateway_appliance_mode_support`          = (Optional\|string) Whether Appliance Mode is enabled. If enabled, a traffic flow between a source and a destination uses the same Availability Zone for the VPC attachment for the lifetime of that flow. Valid values: `disable` (default) and `enable`.<br>- `transit_gateway_dns_support`                     = (Optional\|string) DNS Support is used if you need the VPC to resolve public IPv4 DNS host names to private IPv4 addresses when queried from instances in another VPC attached to the transit gateway. Valid values: `enable` (default) and `disable`.<br><br>Example:<pre>subnets = {<br>  public = {<br>    netmask                   = 24<br>    nat_gateway_configuration = "single_az"<br>    route_to_transit_gateway  = ["10.1.0.0/16"]<br>  }<br><br>  private = {<br>    netmask                  = 24<br>    route_to_nat             = true<br>    route_to_transit_gateway = ["10.1.0.0/16"]<br>  }<br><br>  transit_gateway = {<br>    netmask                                         = 24<br>    transit_gateway_id                              = aws_ec2_transit_gateway.example.id<br>    route_to_nat                                    = false<br>    transit_gateway_default_route_table_association = true<br>    transit_gateway_default_route_table_propagation = true<br>  }<br>}</pre> | `any` | n/a | yes |
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
| <a name="output_multi_private_subnet_attributes_by_az"></a> [multi\_private\_subnet\_attributes\_by\_az](#output\_multi\_private\_subnet\_attributes\_by\_az) | Map of all private subnets containing their attributes.<br><br>Example:<pre>private_subnet_attributes = {<br>  "private/us-east-1a" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-04a86315c4839b519"<br>    "assign_ipv6_address_on_creation" = false<br>    ...<br>    <all attributes of subnet: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#attributes-reference><br>  }<br>  "us-east-1b" = {...)<br>}</pre> |
| <a name="output_nat_gateway_attributes_by_az"></a> [nat\_gateway\_attributes\_by\_az](#output\_nat\_gateway\_attributes\_by\_az) | Map of nat gateway resource attributes by AZ.<br><br>Example:<pre>nat_gateway_attributes_by_az = {<br>  "us-east-1a" = {<br>    "allocation_id" = "eipalloc-0e8b20303eea88b13"<br>    "connectivity_type" = "public"<br>    "id" = "nat-0fde39f9550f4abb5"<br>    "network_interface_id" = "eni-0d422727088bf9a86"<br>    "private_ip" = "10.0.3.40"<br>    "public_ip" = <><br>    "subnet_id" = "subnet-0f11c92e439c8ab4a"<br>    "tags" = tomap({<br>      "Name" = "nat-my-public-us-east-1a"<br>    })<br>    "tags_all" = tomap({<br>      "Name" = "nat-my-public-us-east-1a"<br>    })<br>  }<br>  "us-east-1b" = { ... }<br>}</pre> |
| <a name="output_private_subnet_cidrs_by_az"></a> [private\_subnet\_cidrs\_by\_az](#output\_private\_subnet\_cidrs\_by\_az) | Map of private subnet resource attributes grouped by "type/AZ".<br><br>Example:<pre>private_subnets = {<br>  "private/us-east-1a" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-028d7f65ccc12ff98"<br>    "vpc_id" = "vpc-05601d7778af1ba9c"<br>    ...<br>  }<br>  "private/us-east-1b" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-0091597b2b4c78dda"<br>    ...<br>  }</pre> |
| <a name="output_public_subnet_attributes_by_az"></a> [public\_subnet\_attributes\_by\_az](#output\_public\_subnet\_attributes\_by\_az) | Map of all public subnets containing their attributes.<br><br>Example:<pre>public_subnet_attributes = {<br>  "us-east-1a" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-04a86315c4839b519"<br>    "assign_ipv6_address_on_creation" = false<br>    ...<br>    <all attributes of subnet: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#attributes-reference><br>  }<br>  "us-east-1b" = {...)<br>}</pre> |
| <a name="output_public_subnet_cidrs_by_az"></a> [public\_subnet\_cidrs\_by\_az](#output\_public\_subnet\_cidrs\_by\_az) | Map of public subnet resource attributes grouped by AZ.<br><br>Example:<pre>public_subnets = {<br>  "us-east-1a" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-028d7f65ccc12ff98"<br>    "vpc_id" = "vpc-05601d7778af1ba9c"<br>    ...<br>  }<br>  "us-east-1b" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-0091597b2b4c78dda"<br>    ...<br>  }</pre> |
| <a name="output_rt_attributes_by_type_by_az"></a> [rt\_attributes\_by\_type\_by\_az](#output\_rt\_attributes\_by\_type\_by\_az) | Map of route tables by type => az => route table attributes. Example usage: module.vpc.route\_table\_by\_subnet\_type.private.id<br><br>Example:<pre>route_table_attributes_by_type_by_az = {<br>  "private" = {<br>    "us-east-1a" = {<br>      "id" = "rtb-0e77040c0598df003"<br>      "route_table_id" = "rtb-0e77040c0598df003"<br>      "tags" = tolist([<br>        {<br>          "key" = "Name"<br>          "value" = "private-us-east-1a"<br>        },<br>      ])<br>      "vpc_id" = "vpc-033e054f49409592a"<br>    }<br>    "us-east-1b" = { ... }<br>  "public" = { ... }</pre> |
| <a name="output_tgw_subnet_attributes_by_az"></a> [tgw\_subnet\_attributes\_by\_az](#output\_tgw\_subnet\_attributes\_by\_az) | Map of all tgw subnets containing their attributes.<br><br>Example:<pre>tgw_subnet_attributes = {<br>  "us-east-1a" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-04a86315c4839b519"<br>    "assign_ipv6_address_on_creation" = false<br>    ...<br>    <all attributes of subnet: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#attributes-reference><br>  }<br>  "us-east-1b" = {...)<br>}</pre> |
| <a name="output_tgw_subnet_cidrs_by_az"></a> [tgw\_subnet\_cidrs\_by\_az](#output\_tgw\_subnet\_cidrs\_by\_az) | Map of transit gateway subnet resource attributes grouped by AZ.<br><br>Example:<pre>tgw_subnets = {<br>  "us-east-1a" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-028d7f65ccc12ff98"<br>    "vpc_id" = "vpc-05601d7778af1ba9c"<br>    ...<br>  }<br>  "us-east-1b" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-0091597b2b4c78dda"<br>    ...<br>  }</pre> |
| <a name="output_transit_gateway_attachment_id"></a> [transit\_gateway\_attachment\_id](#output\_transit\_gateway\_attachment\_id) | Transit gateway attachment id. |
| <a name="output_vpc_attributes"></a> [vpc\_attributes](#output\_vpc\_attributes) | VPC resource attributes. Full output of aws\_vpc. |
<!-- END_TF_DOCS -->