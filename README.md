<!-- BEGIN_TF_DOCS -->
# AWS VPC Module

This module can be used to deploy a pragmatic VPC with various subnets types in # AZs. Common deployment examples can be found in [examples/](https://github.com/aws-ia/terraform-aws-vpc/tree/main/examples).

<i>Note: For information regarding the 4.0 upgrade see our [upgrade guide](https://github.com/aws-ia/terraform-aws-vpc/blob/main/docs/UPGRADE-GUIDE-4.0.md).</i>

## Usage

The example below builds a dual-stack VPC with public and private subnets in 3 AZs. Each subnet calculates an IPv4 CIDR based on the `netmask` argument passed, and an IPv6 CIDR with a /64 prefix length. The public subnets build NAT gateways in each AZ but optionally can be switched to `single_az`. An Egress-only Internet gateway is created by using the variable `vpc_egress_only_internet_gateway`.

```hcl
module "vpc" {
  source   = "aws-ia/vpc/aws"
  version = ">= 4.2.0"

  name                                 = "multi-az-vpc"
  cidr_block                           = "10.0.0.0/16"
  vpc_assign_generated_ipv6_cidr_block = true
  vpc_egress_only_internet_gateway     = true
  az_count                             = 3

  subnets = {
    # Dual-stack subnet
    public = {
      name_prefix               = "my_public" # omit to prefix with "public"
      netmask                   = 24
      assign_ipv6_cidr          = true
      nat_gateway_configuration = "all_azs" # options: "single_az", "none"
    }
    # IPv4 only subnet
    private = {
      # omitting name_prefix defaults value to "private"
      # name_prefix  = "private_with_egress"
      netmask      = 24
      connect_to_public_natgw = true
    }
    # IPv6-only subnet
    private_ipv6 = {
      ipv6_native      = true
      assign_ipv6_cidr = true
      connect_to_eigw  = true
    }
  }

  vpc_flow_logs = {
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
  }
}
```

## Reserved Subnet Key Names

There are 3 reserved keys for subnet key names in var.subnets corresponding to types "public", "transit\_gateway", and "core\_network" [(an AWS Cloud WAN feature)](https://docs.aws.amazon.com/vpc/latest/cloudwan/cloudwan-networks-working-with.html). Other custom subnet key names are valid are and those subnets will be private subnets.

```hcl
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
    connect_to_public_natgw = true
  }

  # can be any valid key name
  privatetwo = {
    # omitting name_prefix defaults value to "privatetwo"
    # name_prefix  = "private"
    netmask      = 24
  }
```

```hcl
transit_gateway_id = <>
transit_gateway_routes = {
  private = "0.0.0.0/0"
  vpce    = "pl-123"
}
transit_gateway_ipv6_routes = {
  private = "::/0"
}

subnets = {
  private = {
    netmask          = 24
    assign_ipv6_cidr = true
  }
  vpce = { netmask = 24}

  transit_gateway = {
    netmask                                         = 28
    assign_ipv6_cidr                                = true
    transit_gateway_default_route_table_association = true
    transit_gateway_default_route_table_propagation = true
    transit_gateway_appliance_mode_support          = "enable"
    transit_gateway_dns_support                     = "disable"

    tags = {
      subnet_type = "tgw"
    }
}
```

```hcl
core_network = {
  id  = <>
  arn = <>
}
core_network_routes = {
  workload = "pl-123"
}
core_network_ipv6_routes = {
  workload = "::/0"
}

subnets = {
  workload = {
    name_prefix      = "workload-private"
    netmask          = 24
    assign_ipv6_cidr = true
  }

  core_network = {
    netmask                = 28
    assign_ipv6_cidr       = true
    appliance_mode_support = false
    require_acceptance     = true
    accept_attachment      = true

    tags = {
      env = "prod"
    }
}
```

## Updating a VPC with new or removed subnets

If using `netmask` or `assign_ipv6_cidr` to calculate subnets and you wish to either add or remove subnets (ex: adding / removing an AZ), you may have to change from using `netmask` / `assign_ipv6_cidr` for some subnets and set to explicit instead. Private subnets are always calculated before public.

When changing to explicit cidrs, subnets are always ordered by AZ. `0` -> a, `1` -> b, etc.

Example: Changing from 2 azs to 3

Before:
```hcl
cidr_block                           = "10.0.0.0/16"
vpc_assign_generated_ipv6_cidr_block = true
az_count                             = 2

subnets = {
  public = {
    netmask          = 24
    assign_ipv6_cidr = true
  }

  private = {
   netmask          = 24
   assign_ipv6_cidr = true
  }
}
```

After:
```hcl
cidr_block                           = "10.0.0.0/16"
vpc_assign_generated_ipv6_cidr_block = true
az_count = 3

subnets = {
  public = {
    cidrs      = ["10.0.0.0/24", "10.0.1.0/24", "10.0.4.0/24"]
    ipv6_cidrs = ["2a05:d01c:bc3:b200::/64", "2a05:d01c:bc3:b201::/64", "2a05:d01c:bc3:b204::/64"]
  }

  private = {
    cidrs      = ["10.0.2.0/24", "10.0.3.0/24", "10.0.5.0/24"]
    ipv6_cidrs = ["2a05:d01c:bc3:b202::/64", "2a05:d01c:bc3:b203::/64", "2a05:d01c:bc3:b205::/64"]
  }
}
```

The above example will cause only creating 2 new subnets in az `c` of the region being used.

## Output usage examples

The outputs in this module attempt to align to a methodology of outputting resource attributes in a reasonable collection. The benefit of this is that, most likely, attributes you want access to are already present without having to create new `output {}` for each possible attribute. The [potential] downside is that you will have to extract it yourself using HCL logic. Below are some common examples:

For more examples and explanation see [output docs]((https://github.com/aws-ia/terraform-aws-vpc/blob/main/docs/how-to-use-module-outputs.md)

### Extracting subnet IDs for private subnets

Example Configuration:
```terraform
module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 4.2.0"

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

# Common Errors and their Fixes

## Error creating routes to Core Network

Error:

> error creating Route in Route Table (rtb-xxx) with destination (YYY): InvalidCoreNetworkArn.NotFound: The core network arn 'arn:aws:networkmanager::XXXX:core-network/core-network-YYYYY' does not exist.

This happens when the Core Network's VPC attachment requires acceptance, so it's not possible to create the routes in the VPC until the attachment is accepted. Check the following:

* If the VPC attachment requires acceptance and you want the module to automatically accept it, configure `require_acceptance` and `accept_attachment` to `true`.

```terraform
subnets = {
  core_network = {
    netmask            = 28
    assign_ipv6_cidr   = true
    require_acceptance = true
    accept_attachment  = true
  }
}
```

* If the VPC attachment requires acceptance but you want to accept it outside the module, first configure `require_acceptance` to `true` and `accept_attachment` to `false`.

```terraform
subnets = {
  core_network = {
    netmask            = 28
    assign_ipv6_cidr   = true
    require_acceptance = true
    accept_attachment  = true
  }
}
```

After you apply and the attachment is accepted (outside the module), change the subnet configuration with `require_acceptance` to `false`.

```terraform
subnets = {
  core_network = {
    netmask            = 28
    assign_ipv6_cidr   = true
    require_acceptance = false
  }
}
```

* Alternatively, you can also not configure any subnet route (`var.core_network_routes`) to the Core Network until the attachment gets accepted.

# Contributing

Please see our [developer documentation](https://github.com/aws-ia/terraform-aws-vpc/blob/main/contributing.md) for guidance on contributing to this module.

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
| <a name="module_calculate_subnets"></a> [calculate\_subnets](#module\_calculate\_subnets) | ./modules/calculate_subnets | n/a |
| <a name="module_calculate_subnets_ipv6"></a> [calculate\_subnets\_ipv6](#module\_calculate\_subnets\_ipv6) | ./modules/calculate_subnets_ipv6 | n/a |
| <a name="module_flow_logs"></a> [flow\_logs](#module\_flow\_logs) | ./modules/flow_logs | n/a |
| <a name="module_subnet_tags"></a> [subnet\_tags](#module\_subnet\_tags) | aws-ia/label/aws | 0.0.5 |
| <a name="module_tags"></a> [tags](#module\_tags) | aws-ia/label/aws | 0.0.5 |
| <a name="module_vpc_lattice_tags"></a> [vpc\_lattice\_tags](#module\_vpc\_lattice\_tags) | aws-ia/label/aws | 0.0.5 |

## Resources

| Name | Type |
|------|------|
| [aws_ec2_transit_gateway_vpc_attachment.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |
| [aws_egress_only_internet_gateway.eigw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/egress_only_internet_gateway) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_networkmanager_attachment_accepter.cwan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_attachment_accepter) | resource |
| [aws_networkmanager_vpc_attachment.cwan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_vpc_attachment) | resource |
| [aws_route.cwan_to_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.ipv6_private_to_cwan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.ipv6_private_to_tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.ipv6_public_to_cwan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.ipv6_public_to_tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.private_to_cwan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.private_to_egress_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.private_to_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.private_to_tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_ipv6_to_igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_to_cwan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_to_igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_to_tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.tgw_to_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.cwan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.cwan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.cwan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_ipv4_cidr_block_association.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipv4_cidr_block_association) | resource |
| [aws_vpclattice_service_network_vpc_association.vpc_lattice_service_network_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_service_network_vpc_association) | resource |
| [aws_availability_zones.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Searches region for # of AZs to use and takes a slice based on count. Assume slice is sorted a-z. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name to give VPC. Note: does not effect subnet names, which get assigned name based on name\_prefix. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Configuration of subnets to build in VPC. 1 Subnet per AZ is created. Subnet types are defined as maps with the available keys: "private", "public", "transit\_gateway", "core\_network". Each Subnet type offers its own set of available arguments detailed below.<br><br>**Attributes shared across subnet types:**<br>- `cidrs`            = (Optional\|list(string)) **Cannot set if `netmask` is set.** List of IPv4 CIDRs to set to subnets. Count of CIDRs defined must match quantity of azs in `az_count`.<br>- `netmask`          = (Optional\|Int) **Cannot set if `cidrs` is set.** Netmask of the `var.cidr_block` to calculate for each subnet.<br>- `assign_ipv6_cidr` = (Optional\|bool) **Cannot set if `ipv6_cidrs` is set.** If true, it will calculate a /64 block from the IPv6 VPC CIDR to set in the subnets.<br>- `ipv6_cidrs`       = (Optional\|list(string)) **Cannot set if `assign_ipv6_cidr` is set.** List of IPv6 CIDRs to set to subnets. The subnet size must use a /64 prefix length. Count of CIDRs defined must match quantity of azs in `az_count`.<br>- `name_prefix`      = (Optional\|String) A string prefix to use for the name of your subnet and associated resources. Subnet type key name is used if omitted (aka private, public, transit\_gateway). Example `name_prefix = "private"` for `var.subnets.private` is redundant.<br>- `tags`             = (Optional\|map(string)) Tags to set on the subnet and associated resources.<br><br>**Any private subnet type options:**<br>- All shared keys above<br>- `connect_to_public_natgw` = (Optional\|bool) Determines if routes to NAT Gateways should be created. Must also set `var.subnets.public.nat_gateway_configuration` in public subnets.<br>- `ipv6_native`             = (Optional\|bool) Indicates whether to create an IPv6-ony subnet. Either `var.assign_ipv6_cidr` or `var.ipv6_cidrs` should be defined to allocate an IPv6 CIDR block.<br>- `connect_to_eigw`         = (Optional\|bool) Determines if routes to the Egress-only Internet gateway should be created. Must also set `var.vpc_egress_only_internet_gateway`.<br><br>**public subnet type options:**<br>- All shared keys above<br>- `nat_gateway_configuration` = (Optional\|string) Determines if NAT Gateways should be created and in how many AZs. Valid values = `"none"`, `"single_az"`, `"all_azs"`. Default = "none". Must also set `var.subnets.private.connect_to_public_natgw = true`.<br>- `connect_to_igw`            = (Optional\|bool) Determines if the default route (0.0.0.0/0 or ::/0) is created in the public subnets with destination the Internet gateway. Defaults to `true`.<br>- `ipv6_native`               = (Optional\|bool) Indicates whether to create an IPv6-ony subnet. Either `var.assign_ipv6_cidr` or `var.ipv6_cidrs` should be defined to allocate an IPv6 CIDR block.<br>- `map_public_ip_on_launch`   = (Optional\|bool) Specify true to indicate that instances launched into the subnet should be assigned a public IP address. Default to `false`.<br><br>**transit\_gateway subnet type options:**<br>- All shared keys above<br>- `connect_to_public_natgw`                         = (Optional\|string) Determines if routes to NAT Gateways should be created. Specify the CIDR range or a prefix-list-id that you want routed to nat gateway. Usually `0.0.0.0/0`. Must also set `var.subnets.public.nat_gateway_configuration`.<br>- `transit_gateway_default_route_table_association` = (Optional\|bool) Boolean whether the VPC Attachment should be associated with the EC2 Transit Gateway association default route table. This cannot be configured or perform drift detection with Resource Access Manager shared EC2 Transit Gateways.<br>- `transit_gateway_default_route_table_propagation` = (Optional\|bool) Boolean whether the VPC Attachment should propagate routes with the EC2 Transit Gateway propagation default route table. This cannot be configured or perform drift detection with Resource Access Manager shared EC2 Transit Gateways.<br>- `transit_gateway_appliance_mode_support`          = (Optional\|string) Whether Appliance Mode is enabled. If enabled, a traffic flow between a source and a destination uses the same Availability Zone for the VPC attachment for the lifetime of that flow. Valid values: `disable` (default) and `enable`.<br>- `transit_gateway_dns_support`                     = (Optional\|string) DNS Support is used if you need the VPC to resolve public IPv4 DNS host names to private IPv4 addresses when queried from instances in another VPC attached to the transit gateway. Valid values: `enable` (default) and `disable`.<br><br>**core\_network subnet type options:**<br>- All shared keys abovce<br>- `connect_to_public_natgw` = (Optional\|string) Determines if routes to NAT Gateways should be created. Specify the CIDR range or a prefix-list-id that you want routed to nat gateway. Usually `0.0.0.0/0`. Must also set `var.subnets.public.nat_gateway_configuration`.<br>- `appliance_mode_support`  = (Optional\|bool) Indicates whether appliance mode is supported. If enabled, traffic flow between a source and destination use the same Availability Zone for the VPC attachment for the lifetime of that flow. Defaults to `false`.<br>- `require_acceptance`      = (Optional\|bool) Boolean whether the core network VPC attachment to create requires acceptance or not. Defaults to `false`.<br>- `accept_attachment`       = (Optional\|bool) Boolean whether the core network VPC attachment is accepted or not in the segment. Only valid if `require_acceptance` is set to `true`. Defaults to `true`.<br><br>Example:<pre>subnets = {<br>  # Dual-stack subnet<br>  public = {<br>    netmask                   = 24<br>    assign_ipv6_cidr          = true<br>    nat_gateway_configuration = "single_az"<br>  }<br>  # IPv4 only subnet<br>  private = {<br>    netmask                  = 24<br>    connect_to_public_natgw  = true<br>  }<br>  # IPv6 only subnet<br>  ipv6 = {<br>    ipv6_native      = true<br>    assign_ipv6_cidr = true<br>    connect_to_eigw  = true<br>  }<br>  # Transit gateway subnets (dual-stack)<br>  transit_gateway = {<br>    netmask                                         = 24<br>    assign_ipv6_cidr                                = true<br>    connect_to_public_natgw                         = true<br>    transit_gateway_default_route_table_association = true<br>    transit_gateway_default_route_table_propagation = true<br>  }<br>  # Core Network subnets (dual-stack)<br>  core_network = {<br>    netmask                 = 24<br>    assign_ipv6_cidr        = true<br>    connect_to_public_natgw = true<br>    appliance_mode_support  = true<br>    require_acceptance      = true<br>    accept_attachment       = true<br>  }<br>}</pre> | `any` | n/a | yes |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | IPv4 CIDR range to assign to VPC if creating VPC or to associate as a secondary IPv6 CIDR. Overridden by var.vpc\_id output from data.aws\_vpc. | `string` | `null` | no |
| <a name="input_core_network"></a> [core\_network](#input\_core\_network) | AWS Cloud WAN's core network information - to create a VPC attachment. Required when `cloud_wan` subnet is defined. Two attributes are required: the `id` and `arn` of the resource. | <pre>object({<br>    id  = string<br>    arn = string<br>  })</pre> | <pre>{<br>  "arn": null,<br>  "id": null<br>}</pre> | no |
| <a name="input_core_network_ipv6_routes"></a> [core\_network\_ipv6\_routes](#input\_core\_network\_ipv6\_routes) | Configuration of IPv6 route(s) to AWS Cloud WAN's core network.<br>For each `public` and/or `private` subnets named in the `subnets` variable, optionally create routes from the subnet to the core network.<br>You can specify either a CIDR range or a prefix-list-id that you want routed to the core network.<br>Example:<pre>core_network_ivp6_routes = {<br>  public  = "::/0"<br>  private = "pl-123"<br>}</pre> | `any` | `{}` | no |
| <a name="input_core_network_routes"></a> [core\_network\_routes](#input\_core\_network\_routes) | Configuration of route(s) to AWS Cloud WAN's core network.<br>For each `public` and/or `private` subnets named in the `subnets` variable, optionally create routes from the subnet to the core network.<br>You can specify either a CIDR range or a prefix-list-id that you want routed to the core network.<br>Example:<pre>core_network_routes = {<br>  public  = "10.0.0.0/8"<br>  private = "pl-123"<br>}</pre> | `any` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | Transit gateway id to attach the VPC to. Required when `transit_gateway` subnet is defined. | `string` | `null` | no |
| <a name="input_transit_gateway_ipv6_routes"></a> [transit\_gateway\_ipv6\_routes](#input\_transit\_gateway\_ipv6\_routes) | Configuration of IPv6 route(s) to transit gateway.<br>For each `public` and/or `private` subnets named in the `subnets` variable,<br>Optionally create routes from the subnet to transit gateway. Specify the CIDR range or a prefix-list-id that you want routed to the transit gateway.<br>Example:<pre>transit_gateway_ipv6_routes = {<br>  public  = "::/0"<br>  private = "pl-123"<br>}</pre> | `any` | `{}` | no |
| <a name="input_transit_gateway_routes"></a> [transit\_gateway\_routes](#input\_transit\_gateway\_routes) | Configuration of route(s) to transit gateway.<br>For each `public` and/or `private` subnets named in the `subnets` variable,<br>Optionally create routes from the subnet to transit gateway. Specify the CIDR range or a prefix-list-id that you want routed to the transit gateway.<br>Example:<pre>transit_gateway_routes = {<br>  public  = "10.0.0.0/8"<br>  private = "pl-123"<br>}</pre> | `any` | `{}` | no |
| <a name="input_vpc_assign_generated_ipv6_cidr_block"></a> [vpc\_assign\_generated\_ipv6\_cidr\_block](#input\_vpc\_assign\_generated\_ipv6\_cidr\_block) | Requests and Amazon-provided IPv6 CIDR block with a /56 prefix length. You cannot specify the range of IP addresses, or the size of the CIDR block. Conflicts with `vpc_ipv6_ipam_pool_id`. | `bool` | `null` | no |
| <a name="input_vpc_egress_only_internet_gateway"></a> [vpc\_egress\_only\_internet\_gateway](#input\_vpc\_egress\_only\_internet\_gateway) | Set to use the Egress-only Internet gateway for all IPv6 traffic going to the Internet. | `bool` | `false` | no |
| <a name="input_vpc_enable_dns_hostnames"></a> [vpc\_enable\_dns\_hostnames](#input\_vpc\_enable\_dns\_hostnames) | Indicates whether the instances launched in the VPC get DNS hostnames. If enabled, instances in the VPC get DNS hostnames; otherwise, they do not. Disabled by default for nondefault VPCs. | `bool` | `true` | no |
| <a name="input_vpc_enable_dns_support"></a> [vpc\_enable\_dns\_support](#input\_vpc\_enable\_dns\_support) | Indicates whether the DNS resolution is supported for the VPC. If enabled, queries to the Amazon provided DNS server at the 169.254.169.253 IP address, or the reserved IP address at the base of the VPC network range "plus two" succeed. If disabled, the Amazon provided DNS service in the VPC that resolves public DNS hostnames to IP addresses is not enabled. Enabled by default. | `bool` | `true` | no |
| <a name="input_vpc_flow_logs"></a> [vpc\_flow\_logs](#input\_vpc\_flow\_logs) | Whether or not to create VPC flow logs and which type. Options: "cloudwatch", "s3", "none". By default creates flow logs to `cloudwatch`. Variable overrides null value types for some keys, defined in defaults.tf. | <pre>object({<br>    name_override   = optional(string, "")<br>    log_destination = optional(string)<br>    iam_role_arn    = optional(string)<br>    kms_key_id      = optional(string)<br><br>    log_destination_type = string<br>    retention_in_days    = optional(number)<br>    tags                 = optional(map(string))<br>    traffic_type         = optional(string, "ALL")<br>    destination_options = optional(object({<br>      file_format                = optional(string, "plain-text")<br>      hive_compatible_partitions = optional(bool, false)<br>      per_hour_partition         = optional(bool, false)<br>    }))<br>  })</pre> | <pre>{<br>  "log_destination_type": "none"<br>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to use if not creating VPC. | `string` | `null` | no |
| <a name="input_vpc_instance_tenancy"></a> [vpc\_instance\_tenancy](#input\_vpc\_instance\_tenancy) | The allowed tenancy of instances launched into the VPC. | `string` | `"default"` | no |
| <a name="input_vpc_ipv4_ipam_pool_id"></a> [vpc\_ipv4\_ipam\_pool\_id](#input\_vpc\_ipv4\_ipam\_pool\_id) | Set to use IPAM to get an IPv4 CIDR block. | `string` | `null` | no |
| <a name="input_vpc_ipv4_netmask_length"></a> [vpc\_ipv4\_netmask\_length](#input\_vpc\_ipv4\_netmask\_length) | Set to use IPAM to get an IPv4 CIDR block using a specified netmask. Must be set with var.vpc\_ipv4\_ipam\_pool\_id. | `string` | `null` | no |
| <a name="input_vpc_ipv6_cidr_block"></a> [vpc\_ipv6\_cidr\_block](#input\_vpc\_ipv6\_cidr\_block) | IPv6 CIDR range to assign to VPC if creating VPC. You need to use `vpc_ipv6_ipam_pool_id` and set explicitly the CIDR block to use, or derived from IPAM using using `vpc_ipv6_netmask_length`. | `string` | `null` | no |
| <a name="input_vpc_ipv6_ipam_pool_id"></a> [vpc\_ipv6\_ipam\_pool\_id](#input\_vpc\_ipv6\_ipam\_pool\_id) | Set to use IPAM to get an IPv6 CIDR block. | `string` | `null` | no |
| <a name="input_vpc_ipv6_netmask_length"></a> [vpc\_ipv6\_netmask\_length](#input\_vpc\_ipv6\_netmask\_length) | Set to use IPAM to get an IPv6 CIDR block using a specified netmask. Must be set with `var.vpc_ipv6_ipam_pool_id`. | `string` | `null` | no |
| <a name="input_vpc_lattice"></a> [vpc\_lattice](#input\_vpc\_lattice) | Amazon VPC Lattice Service Network VPC association. You can only associate one Service Network to the VPC. This association also support Security Groups (more than 1).<br>This variable expects the following attributes:<br>- `service_network_identifier` = (Required\|string) The ID or ARN of the Service Network to associate. You must use the ARN if the Service Network and VPC resources are in different AWS Accounts.<br>- `security_group_ids`         = (Optional\|list(string)) The IDs of the security groups to attach to the association.<br>- `tags`                       = (Optional\|map(string)) Tags to set on the Lattice VPC association resource. | `any` | `{}` | no |
| <a name="input_vpc_secondary_cidr"></a> [vpc\_secondary\_cidr](#input\_vpc\_secondary\_cidr) | If `true` the module will create a `aws_vpc_ipv4_cidr_block_association` and subnets for that secondary cidr. If using IPAM for both primary and secondary CIDRs, you may only call this module serially (aka using `-target`, etc). | `bool` | `false` | no |
| <a name="input_vpc_secondary_cidr_natgw"></a> [vpc\_secondary\_cidr\_natgw](#input\_vpc\_secondary\_cidr\_natgw) | If attaching a secondary IPv4 CIDR instead of creating a VPC, you can map private/ tgw subnets to your public NAT GW with this argument. Simply pass the output `nat_gateway_attributes_by_az`, ex: `vpc_secondary_cidr_natgw = module.vpc.natgw_id_per_az`. If you did not build your primary with this module, you must construct a map { az : { id : nat-123asdb }} for each az. | `any` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azs"></a> [azs](#output\_azs) | List of AZs where subnets are created. |
| <a name="output_core_network_attachment"></a> [core\_network\_attachment](#output\_core\_network\_attachment) | AWS Cloud WAN's core network attachment. Full output of aws\_networkmanager\_vpc\_attachment. |
| <a name="output_core_network_subnet_attributes_by_az"></a> [core\_network\_subnet\_attributes\_by\_az](#output\_core\_network\_subnet\_attributes\_by\_az) | Map of all core\_network subnets containing their attributes.<br><br>Example:<pre>core_network_subnet_attributes_by_az = {<br>  "us-east-1a" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-04a86315c4839b519"<br>    "assign_ipv6_address_on_creation" = false<br>    ...<br>    <all attributes of subnet: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#attributes-reference><br>  }<br>  "us-east-1b" = {...)<br>}</pre> |
| <a name="output_egress_only_internet_gateway"></a> [egress\_only\_internet\_gateway](#output\_egress\_only\_internet\_gateway) | Egress-only Internet gateway attributes. Full output of aws\_egress\_only\_internet\_gateway. |
| <a name="output_flow_log_attributes"></a> [flow\_log\_attributes](#output\_flow\_log\_attributes) | Flow Log information. |
| <a name="output_internet_gateway"></a> [internet\_gateway](#output\_internet\_gateway) | Internet gateway attributes. Full output of aws\_internet\_gateway. |
| <a name="output_nat_gateway_attributes_by_az"></a> [nat\_gateway\_attributes\_by\_az](#output\_nat\_gateway\_attributes\_by\_az) | Map of nat gateway resource attributes by AZ.<br><br>Example:<pre>nat_gateway_attributes_by_az = {<br>  "us-east-1a" = {<br>    "allocation_id" = "eipalloc-0e8b20303eea88b13"<br>    "connectivity_type" = "public"<br>    "id" = "nat-0fde39f9550f4abb5"<br>    "network_interface_id" = "eni-0d422727088bf9a86"<br>    "private_ip" = "10.0.3.40"<br>    "public_ip" = <><br>    "subnet_id" = "subnet-0f11c92e439c8ab4a"<br>    "tags" = tomap({<br>      "Name" = "nat-my-public-us-east-1a"<br>    })<br>    "tags_all" = tomap({<br>      "Name" = "nat-my-public-us-east-1a"<br>    })<br>  }<br>  "us-east-1b" = { ... }<br>}</pre> |
| <a name="output_natgw_id_per_az"></a> [natgw\_id\_per\_az](#output\_natgw\_id\_per\_az) | Map of nat gateway IDs for each resource. Will be duplicate ids if your var.subnets.public.nat\_gateway\_configuration = "single\_az".<br><br>Example:<pre>natgw_id_per_az = {<br>  "us-east-1a" = {<br>    "id" = "nat-0fde39f9550f4abb5"<br>  }<br>  "us-east-1b" = {<br>    "id" = "nat-0fde39f9550f4abb5"<br>   }<br>}</pre> |
| <a name="output_private_subnet_attributes_by_az"></a> [private\_subnet\_attributes\_by\_az](#output\_private\_subnet\_attributes\_by\_az) | Map of all private subnets containing their attributes.<br><br>Example:<pre>private_subnet_attributes_by_az = {<br>  "private/us-east-1a" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-04a86315c4839b519"<br>    "assign_ipv6_address_on_creation" = false<br>    ...<br>    <all attributes of subnet: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#attributes-reference><br>  }<br>  "us-east-1b" = {...)<br>}</pre> |
| <a name="output_public_subnet_attributes_by_az"></a> [public\_subnet\_attributes\_by\_az](#output\_public\_subnet\_attributes\_by\_az) | Map of all public subnets containing their attributes.<br><br>Example:<pre>public_subnet_attributes_by_az = {<br>  "us-east-1a" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-04a86315c4839b519"<br>    "assign_ipv6_address_on_creation" = false<br>    ...<br>    <all attributes of subnet: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#attributes-reference><br>  }<br>  "us-east-1b" = {...)<br>}</pre> |
| <a name="output_rt_attributes_by_type_by_az"></a> [rt\_attributes\_by\_type\_by\_az](#output\_rt\_attributes\_by\_type\_by\_az) | Map of route tables by type => az => route table attributes. Example usage: module.vpc.rt\_attributes\_by\_type\_by\_az.private.id<br><br>Example:<pre>rt_attributes_by_type_by_az = {<br>  "private" = {<br>    "us-east-1a" = {<br>      "id" = "rtb-0e77040c0598df003"<br>      "tags" = tolist([<br>        {<br>          "key" = "Name"<br>          "value" = "private-us-east-1a"<br>        },<br>      ])<br>      "vpc_id" = "vpc-033e054f49409592a"<br>      ...<br>      <all attributes of route: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table#attributes-reference><br>    }<br>    "us-east-1b" = { ... }<br>  "public" = { ... }</pre> |
| <a name="output_tgw_subnet_attributes_by_az"></a> [tgw\_subnet\_attributes\_by\_az](#output\_tgw\_subnet\_attributes\_by\_az) | Map of all tgw subnets containing their attributes.<br><br>Example:<pre>tgw_subnet_attributes_by_az = {<br>  "us-east-1a" = {<br>    "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-04a86315c4839b519"<br>    "assign_ipv6_address_on_creation" = false<br>    ...<br>    <all attributes of subnet: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#attributes-reference><br>  }<br>  "us-east-1b" = {...)<br>}</pre> |
| <a name="output_transit_gateway_attachment_id"></a> [transit\_gateway\_attachment\_id](#output\_transit\_gateway\_attachment\_id) | Transit gateway attachment id. |
| <a name="output_vpc_attributes"></a> [vpc\_attributes](#output\_vpc\_attributes) | VPC resource attributes. Full output of aws\_vpc. |
| <a name="output_vpc_lattice_service_network_association"></a> [vpc\_lattice\_service\_network\_association](#output\_vpc\_lattice\_service\_network\_association) | VPC Lattice Service Network VPC association. Full output of aws\_vpclattice\_service\_network\_vpc\_association |
<!-- END_TF_DOCS -->