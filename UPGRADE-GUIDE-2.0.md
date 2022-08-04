# Changes from 1.x to 2.x

- Ability to create arbitrary amounts of subnets types. Previously was only capable of 3 types: public, private, transit gateway. The terms `public` and `transit_gateway` are reserved keywords for those subnet types and all other keys used in var.subnets.<> are assumed to be type **private**.
- Many private subnet related resources had to be renamed. Most changes are accomplished programatically using a [moved blocks](https://www.terraform.io/language/modules/develop/refactoring) but some require manual `terraform state mv` commands. see below.
- Can pass cidr or prefix list id to any `route_to_nat` argument. Previously was a boolean that assumed `"0.0.0.0/0"` as the destination cidr.
- Can pass cidr or prefix list id to `route_to_transit_gateway` argument. Previously was a list of CIDRs that could only accept 1 item.
- Many changes to Outputs available. Removed outputs marked as deprecated, separated grouped subnet attribute outputs into 3 `public_`, `tgw_`, and `private_`. Since you can have several private subnet declarations we group based on the name scheme `<your_key_name>/az`.

# Required Changes to Make

Using the [transit gateway example](https://github.com/aws-ia/terraform-aws-vpc/blob/main/examples/transit_gateway/main.tf) if upgrading to v2 you must make the following changes

_Note: Due to a [bug discovered in v1](https://github.com/aws-ia/terraform-aws-vpc/issues/65), it was not actually possible to manage ipam VPCs. Therefore, we do not support ipam related upgrades to v2. Please do a full rebuild._

## HCL changes

### route_to_transit_gateway

Before: `route_to_transit_gateway  = ["10.0.0.0/8"]`

After : `route_to_transit_gateway  = "10.0.0.0/8"`


### route_to_nat

Before: `route_to_nat = true`

After : `route_to_nat = "0.0.0.0/0"`

## Statefile Changes

Previously, we used the user provided CIDR range as the key in our `for_each` loop for the below 2 resources. You must `mv` the resources in your statefile to the new names. This was a learning for us, as such, we will use predicatble values for future iterables. You can learn more about how to customize our `moved.tf` file [here.](https://github.com/aws-ia/terraform-aws-vpc/tree/main/moved_block_rendering)

The commands below assume region `us-east-1`, you must adjust and run for your reach and each AZ. Ergo: if `az_count = 2` then you must run 4 total commands:

### **private_to_tgw** move command

_note: must adjust and run per AZ_

`terraform state mv 'module.vpc.aws_route.private_to_tgw["us-east-1a:10.0.0.0/8"]' 'module.vpc.aws_route.private_to_tgw["private/us-east-1a"]'`

### **public_to_tgw** move command

_note: must adjust and run per AZ_

`terraform state mv 'module.vpc.aws_route.public_to_tgw["us-east-1b:10.0.0.0/8"]' 'module.vpc.aws_route.public_to_tgw["us-east-1b"]'`


# Potential Error Messages and Remediation

### Incorrect Attribute Types

>  Error: Incorrect attribute value type

Adjust values for:

- `route_to_transit_gateway`
- `route_to_nat`

### Resources will be destroyed

> module.vpc.aws_route.private_to_tgw["us-east-1a:10.0.0.0/8"] will be destroyed

> module.vpc.aws_route.public_to_tgw["us-east-1b:10.0.0.0/8"] will be destroyed

Remediation: See the move commands above.


### Invalid `for_each` argument

This problem is nuanced. It likely indicates that youre trying to use a prefix list as a `route_to_nat` or `route_to_transit_gateway` value in a subnet argument or transit gateway id. If you're attempting to create a resource and use it as a value in any of subnet definition, you must first [target create](https://learn.hashicorp.com/tutorials/terraform/resource-targeting) those resources. This includes both `aws_ec2_managed_prefix_list` and `aws_ec2_transit_gateway`.

Alternative to target creates, see the [transit_gateway test](https://github.com/aws-ia/terraform-aws-vpc/blob/main/test/examples_transit_gateway__test.go) for an example, we create both in a separate root and pass as variables

 >│ Error: Invalid for_each argument
 │
 │   on ../../main.tf line 167, in resource "aws_route" "private_to_tgw":
 │  167:   for_each = toset(try(local.private_subnet_key_names_tgw_routed, []))
 │     ├────────────────
 │     │ local.private_subnet_key_names_tgw_routed will be known only after apply

 > var.subnets.public.route_to_transit_gateway is a string, known only after apply
