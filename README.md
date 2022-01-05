## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.68 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | ~> 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.68 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | ~> 0.9 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_tags"></a> [tags](#module\_tags) | github.com/aws-ia/terraform-aws-label | 0.0.4 |
| <a name="module_vpc_endpoints"></a> [vpc\_endpoints](#module\_vpc\_endpoints) | aws-ia/vpc_endpoints/aws | >= 0.1.1 |

## Resources

| Name | Type |
|------|------|
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_nat_gateway.nat_gw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_network_acl_rule.private_a_inbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.private_a_outbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.private_b_inbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.private_b_outbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_inbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_outbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_route.private_a_nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.private_b_nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [awscc_ec2_internet_gateway.gw](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_internet_gateway) | resource |
| [awscc_ec2_network_acl.private_a](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_network_acl) | resource |
| [awscc_ec2_network_acl.private_b](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_network_acl) | resource |
| [awscc_ec2_network_acl.public](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_network_acl) | resource |
| [awscc_ec2_route_table.private_a](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_route_table) | resource |
| [awscc_ec2_route_table.private_b](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_route_table) | resource |
| [awscc_ec2_route_table.public](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_route_table) | resource |
| [awscc_ec2_subnet.private_a](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet) | resource |
| [awscc_ec2_subnet.private_b](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet) | resource |
| [awscc_ec2_subnet.public](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet) | resource |
| [awscc_ec2_subnet_route_table_association.private_a](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet_route_table_association) | resource |
| [awscc_ec2_subnet_route_table_association.private_b](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet_route_table_association) | resource |
| [awscc_ec2_subnet_route_table_association.public](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_subnet_route_table_association) | resource |
| [awscc_ec2_vpc.main](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_vpc) | resource |
| [random_string.vpc_name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | A list of availability zones to use for subnets. If this is not provided availability zones for subnets will be automatically selected | `list(string)` | `null` | no |
| <a name="input_cidr"></a> [cidr](#input\_cidr) | The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden | `string` | `"10.0.0.0/16"` | no |
| <a name="input_create_igw"></a> [create\_igw](#input\_create\_igw) | If set to false no IGW will be created for the public subnets. Setting this to false will also disable NAT gateways on private subnets, as NAT gateways require IGW in public subnets | `bool` | `true` | no |
| <a name="input_create_nat_gateways_private_a"></a> [create\_nat\_gateways\_private\_a](#input\_create\_nat\_gateways\_private\_a) | If set to false no NAT gateways will be created for the private\_a subnets | `bool` | `true` | no |
| <a name="input_create_nat_gateways_private_b"></a> [create\_nat\_gateways\_private\_b](#input\_create\_nat\_gateways\_private\_b) | If set to false no NAT gateways will be created for the private\_b subnets | `bool` | `false` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Controls if VPC should be created (it affects almost all resources) | `bool` | `true` | no |
| <a name="input_enable_dns_hostnames"></a> [enable\_dns\_hostnames](#input\_enable\_dns\_hostnames) | Should be true to enable DNS hostnames in the VPC | `bool` | `true` | no |
| <a name="input_enable_dns_support"></a> [enable\_dns\_support](#input\_enable\_dns\_support) | Should be true to enable DNS support in the VPC | `bool` | `true` | no |
| <a name="input_enabled_gateway_endpoints"></a> [enabled\_gateway\_endpoints](#input\_enabled\_gateway\_endpoints) | List of shortened gateway endpoint names that are to be enabled. Endpoints will be attached to the private\_a and private\_b route tables. Shortened names are the endpoint name excluding the dns style prefix, so "com.amazonaws.us-east-1.s3" would be entered as "s3". For a full list of available endpoint names, see the aws-ia/vpc\_endpoints module on the terraform registry. | `list(string)` | `[]` | no |
| <a name="input_enabled_interface_endpoints"></a> [enabled\_interface\_endpoints](#input\_enabled\_interface\_endpoints) | List of shortened interface endpoint names that are to be enabled. Endpoints will be attached to the private\_b subnets. A dedicated security group will be created (allowing tcp443 ingress from vpc cidr) and outputted as "vpc\_endpoint\_security\_group\_id". Shortened names are the endpoint name excluding the dns style prefix, so "com.amazonaws.us-east-1.s3" would be entered as "s3". For a full list of available endpoint names, see the aws-ia/vpc\_endpoints module on the terraform registry. For advanced configuration options, use the aws-ia/vpc\_endpoints module directly. | `list(string)` | `[]` | no |
| <a name="input_instance_tenancy"></a> [instance\_tenancy](#input\_instance\_tenancy) | A tenancy option for instances launched into the VPC | `string` | `"default"` | no |
| <a name="input_name"></a> [name](#input\_name) | Will be used as a prefix for all resources that require a name field. Should be unique in the region. | `string` | `null` | no |
| <a name="input_private_a_inbound_acl_rules"></a> [private\_a\_inbound\_acl\_rules](#input\_private\_a\_inbound\_acl\_rules) | Private subnet A's inbound network ACLs. Default allows all traffic | `list(map(string))` | <pre>[<br>  {<br>    "cidr_block": "0.0.0.0/0",<br>    "from_port": 0,<br>    "protocol": "-1",<br>    "rule_action": "allow",<br>    "rule_number": 100,<br>    "to_port": 0<br>  }<br>]</pre> | no |
| <a name="input_private_a_outbound_acl_rules"></a> [private\_a\_outbound\_acl\_rules](#input\_private\_a\_outbound\_acl\_rules) | Private subnet A's outbound network ACLs. Default allows all traffic | `list(map(string))` | <pre>[<br>  {<br>    "cidr_block": "0.0.0.0/0",<br>    "from_port": 0,<br>    "protocol": "-1",<br>    "rule_action": "allow",<br>    "rule_number": 100,<br>    "to_port": 0<br>  }<br>]</pre> | no |
| <a name="input_private_b_inbound_acl_rules"></a> [private\_b\_inbound\_acl\_rules](#input\_private\_b\_inbound\_acl\_rules) | Private subnet B's inbound network ACLs. Default allows all traffic | `list(map(string))` | <pre>[<br>  {<br>    "cidr_block": "0.0.0.0/0",<br>    "from_port": 0,<br>    "protocol": "-1",<br>    "rule_action": "allow",<br>    "rule_number": 100,<br>    "to_port": 0<br>  }<br>]</pre> | no |
| <a name="input_private_b_outbound_acl_rules"></a> [private\_b\_outbound\_acl\_rules](#input\_private\_b\_outbound\_acl\_rules) | Private subnet B's outbound network ACLs. Default allows all traffic | `list(map(string))` | <pre>[<br>  {<br>    "cidr_block": "0.0.0.0/0",<br>    "from_port": 0,<br>    "protocol": "-1",<br>    "rule_action": "allow",<br>    "rule_number": 100,<br>    "to_port": 0<br>  }<br>]</pre> | no |
| <a name="input_private_subnet_a_cidrs"></a> [private\_subnet\_a\_cidrs](#input\_private\_subnet\_a\_cidrs) | A list of CIDR blocks to use for private subnets. Default is 3 /19 cidrs from the CIDR range specified in the cidr variable. The number of private subnets is inferred from the number of CIDR's provided. If availability\_zones are specified, must have the same number of elements. If not specified, the number of elements must not be greater than the number of availability zones in the region. | `list(string)` | `null` | no |
| <a name="input_private_subnet_b_cidrs"></a> [private\_subnet\_b\_cidrs](#input\_private\_subnet\_b\_cidrs) | A list of CIDR blocks to use for private subnets. Default is 3 /19 cidrs from the CIDR range specified in the cidr variable. The number of private subnets is inferred from the number of CIDR's provided. | `list(string)` | `null` | no |
| <a name="input_private_subnet_tags"></a> [private\_subnet\_tags](#input\_private\_subnet\_tags) | Additional tags for the private subnets | <pre>list(object({<br>    key   = string,<br>    value = string<br>  }))</pre> | `[]` | no |
| <a name="input_public_inbound_acl_rules"></a> [public\_inbound\_acl\_rules](#input\_public\_inbound\_acl\_rules) | Public subnets inbound network ACLs. Default allows all traffic | `list(map(string))` | <pre>[<br>  {<br>    "cidr_block": "0.0.0.0/0",<br>    "from_port": 0,<br>    "protocol": "-1",<br>    "rule_action": "allow",<br>    "rule_number": 100,<br>    "to_port": 0<br>  }<br>]</pre> | no |
| <a name="input_public_outbound_acl_rules"></a> [public\_outbound\_acl\_rules](#input\_public\_outbound\_acl\_rules) | Public subnets outbound network ACLs. Default allows all traffic | `list(map(string))` | <pre>[<br>  {<br>    "cidr_block": "0.0.0.0/0",<br>    "from_port": 0,<br>    "protocol": "-1",<br>    "rule_action": "allow",<br>    "rule_number": 100,<br>    "to_port": 0<br>  }<br>]</pre> | no |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | A list of CIDR blocks to use for public subnets. Default is 3 /20 cidrs from the CIDR range specified in the cidr variable. The number of public subnets is inferred from the number of CIDR's provided. If availability\_zones are specified, it must have the same number of elements. If not specified, the number of elements must not be greater than the number of availability zones in the region. | `list(string)` | `null` | no |
| <a name="input_public_subnet_tags"></a> [public\_subnet\_tags](#input\_public\_subnet\_tags) | Additional tags for the public subnets | <pre>list(object({<br>    key   = string,<br>    value = string<br>  }))</pre> | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | tags, which could be used for additional tags | <pre>list(object({<br>    key   = string,<br>    value = string<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | List of availability zones names for subnets in this vpc |
| <a name="output_gateway_endpoints"></a> [gateway\_endpoints](#output\_gateway\_endpoints) | map of properties for all enabled gateway endpoints |
| <a name="output_igw_id"></a> [igw\_id](#output\_igw\_id) | ID for IGW attached to public subnets |
| <a name="output_interface_endpoints"></a> [interface\_endpoints](#output\_interface\_endpoints) | map of properties for all enabled interface endpoints |
| <a name="output_nat_eips"></a> [nat\_eips](#output\_nat\_eips) | NAT IP addresses |
| <a name="output_nat_gw_ids"></a> [nat\_gw\_ids](#output\_nat\_gw\_ids) | ID's for NAT gateways attached to private subnets |
| <a name="output_private_a_nat_routes"></a> [private\_a\_nat\_routes](#output\_private\_a\_nat\_routes) | Routes for NAT gateways attached to private\_a subnets |
| <a name="output_private_b_nat_routes"></a> [private\_b\_nat\_routes](#output\_private\_b\_nat\_routes) | Routes for NAT gateways attached to private\_b subnets |
| <a name="output_private_subnet_1a_cidr"></a> [private\_subnet\_1a\_cidr](#output\_private\_subnet\_1a\_cidr) | Private subnet 1A CIDR in Availability Zone 1 |
| <a name="output_private_subnet_1a_id"></a> [private\_subnet\_1a\_id](#output\_private\_subnet\_1a\_id) | Private subnet 1A ID in Availability Zone 1 |
| <a name="output_private_subnet_1a_route_table"></a> [private\_subnet\_1a\_route\_table](#output\_private\_subnet\_1a\_route\_table) | Private subnet 1A route table |
| <a name="output_private_subnet_1b_cidr"></a> [private\_subnet\_1b\_cidr](#output\_private\_subnet\_1b\_cidr) | Private subnet 1B CIDR in Availability Zone 1 |
| <a name="output_private_subnet_1b_id"></a> [private\_subnet\_1b\_id](#output\_private\_subnet\_1b\_id) | Private subnet 1B ID in Availability Zone 1 |
| <a name="output_private_subnet_1b_route_table"></a> [private\_subnet\_1b\_route\_table](#output\_private\_subnet\_1b\_route\_table) | Private subnet 1B route table |
| <a name="output_private_subnet_2a_cidr"></a> [private\_subnet\_2a\_cidr](#output\_private\_subnet\_2a\_cidr) | Private subnet 2A CIDR in Availability Zone 2 |
| <a name="output_private_subnet_2a_id"></a> [private\_subnet\_2a\_id](#output\_private\_subnet\_2a\_id) | Private subnet 2A ID in Availability Zone 2 |
| <a name="output_private_subnet_2a_route_table"></a> [private\_subnet\_2a\_route\_table](#output\_private\_subnet\_2a\_route\_table) | Private subnet 2A route table |
| <a name="output_private_subnet_2b_cidr"></a> [private\_subnet\_2b\_cidr](#output\_private\_subnet\_2b\_cidr) | Private subnet 2B CIDR in Availability Zone 2 |
| <a name="output_private_subnet_2b_id"></a> [private\_subnet\_2b\_id](#output\_private\_subnet\_2b\_id) | Private subnet 2B ID in Availability Zone 2 |
| <a name="output_private_subnet_2b_route_table"></a> [private\_subnet\_2b\_route\_table](#output\_private\_subnet\_2b\_route\_table) | Private subnet 2B route table |
| <a name="output_private_subnet_3a_cidr"></a> [private\_subnet\_3a\_cidr](#output\_private\_subnet\_3a\_cidr) | Private subnet 3A CIDR in Availability Zone 3 |
| <a name="output_private_subnet_3a_id"></a> [private\_subnet\_3a\_id](#output\_private\_subnet\_3a\_id) | Private subnet 3A ID in Availability Zone 3 |
| <a name="output_private_subnet_3a_route_table"></a> [private\_subnet\_3a\_route\_table](#output\_private\_subnet\_3a\_route\_table) | Private subnet 3A route table |
| <a name="output_private_subnet_3b_cidr"></a> [private\_subnet\_3b\_cidr](#output\_private\_subnet\_3b\_cidr) | Private subnet 3B CIDR in Availability Zone 3 |
| <a name="output_private_subnet_3b_id"></a> [private\_subnet\_3b\_id](#output\_private\_subnet\_3b\_id) | Private subnet 3B ID in Availability Zone 3 |
| <a name="output_private_subnet_3b_route_table"></a> [private\_subnet\_3b\_route\_table](#output\_private\_subnet\_3b\_route\_table) | Private subnet 3B route table |
| <a name="output_private_subnet_4a_cidr"></a> [private\_subnet\_4a\_cidr](#output\_private\_subnet\_4a\_cidr) | Private subnet 4A CIDR in Availability Zone 4 |
| <a name="output_private_subnet_4a_id"></a> [private\_subnet\_4a\_id](#output\_private\_subnet\_4a\_id) | Private subnet 4A ID in Availability Zone 4 |
| <a name="output_private_subnet_4a_route_table"></a> [private\_subnet\_4a\_route\_table](#output\_private\_subnet\_4a\_route\_table) | Private subnet 4A route table |
| <a name="output_private_subnet_4b_cidr"></a> [private\_subnet\_4b\_cidr](#output\_private\_subnet\_4b\_cidr) | Private subnet 4B CIDR in Availability Zone 4 |
| <a name="output_private_subnet_4b_id"></a> [private\_subnet\_4b\_id](#output\_private\_subnet\_4b\_id) | Private subnet 4B ID in Availability Zone 4 |
| <a name="output_private_subnet_4b_route_table"></a> [private\_subnet\_4b\_route\_table](#output\_private\_subnet\_4b\_route\_table) | Private subnet 4B route table |
| <a name="output_private_subnet_a_ids"></a> [private\_subnet\_a\_ids](#output\_private\_subnet\_a\_ids) | List of IDs of privateA subnets |
| <a name="output_private_subnet_b_ids"></a> [private\_subnet\_b\_ids](#output\_private\_subnet\_b\_ids) | List of IDs of privateB subnets |
| <a name="output_private_subnet_route_tables"></a> [private\_subnet\_route\_tables](#output\_private\_subnet\_route\_tables) | List of IDs of private subnets |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | List of IDs of private subnets |
| <a name="output_public_subnet_1_cidr"></a> [public\_subnet\_1\_cidr](#output\_public\_subnet\_1\_cidr) | Public subnet 1 CIDR in Availability Zone 1 |
| <a name="output_public_subnet_1_id"></a> [public\_subnet\_1\_id](#output\_public\_subnet\_1\_id) | Public subnet 1 ID in Availability Zone 1 |
| <a name="output_public_subnet_2_cidr"></a> [public\_subnet\_2\_cidr](#output\_public\_subnet\_2\_cidr) | Public subnet 2 CIDR in Availability Zone 2 |
| <a name="output_public_subnet_2_id"></a> [public\_subnet\_2\_id](#output\_public\_subnet\_2\_id) | Public subnet 2 ID in Availability Zone 2 |
| <a name="output_public_subnet_3_cidr"></a> [public\_subnet\_3\_cidr](#output\_public\_subnet\_3\_cidr) | Public subnet 3 CIDR in Availability Zone 3 |
| <a name="output_public_subnet_3_id"></a> [public\_subnet\_3\_id](#output\_public\_subnet\_3\_id) | Public subnet 3 ID in Availability Zone 3 |
| <a name="output_public_subnet_4_cidr"></a> [public\_subnet\_4\_cidr](#output\_public\_subnet\_4\_cidr) | Public subnet 4 CIDR in Availability Zone 4 |
| <a name="output_public_subnet_4_id"></a> [public\_subnet\_4\_id](#output\_public\_subnet\_4\_id) | Public subnet 4 ID in Availability Zone 4 |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of IDs of privateB subnets |
| <a name="output_public_subnet_route_table"></a> [public\_subnet\_route\_table](#output\_public\_subnet\_route\_table) | Public subnet route table |
| <a name="output_vpc_cidr"></a> [vpc\_cidr](#output\_vpc\_cidr) | VPC\_CIDR |
| <a name="output_vpc_endpoint_security_group_id"></a> [vpc\_endpoint\_security\_group\_id](#output\_vpc\_endpoint\_security\_group\_id) | Security group ID that interface endpoints are attached to |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
