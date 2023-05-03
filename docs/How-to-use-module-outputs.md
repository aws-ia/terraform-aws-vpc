# Why our Outputs are so different and how you can use them

The Outputs from this module are designed differently than many other popular modules. Most have 100+ outputs that export individual values for specific uses. This is great because it is simple, straight-forward approach to creating and using output values from a module. This module takes a different design approach, an opinionated one that may cause you to turn your head on first glance but, we believe, is more useful and maintainable in the long run.

## TL;DR How do I use these things?

[See here](#using-the-console-to-explore)

## Implementation details:

Outputs are provided at the _resource_ level and grouped in the most logical way we have considered (please suggest others!). Let us look at a few examples:

- [nat_gateway_attributes_by_az](https://github.com/aws-ia/terraform-aws-vpc/#output_nat_gateway_attributes_by_az):
  * description: Map of nat gateway resource attributes by AZ.

The name of the output explains exactly what you'll get. The attributes of a nat gateway and they're grouped by the name of the availability zone theyre in. You will see this design in most of the outputs. This is because when users make multi-az vpcs the attributes of those resources are most relevant with regard to the AZ theyre in.

### Using the Console to explore

After building the [public_private_flow_logs example](https://registry.terraform.io/modules/aws-ia/vpc/aws/latest/examples/public_private_flow_logs) drop into the [console](https://developer.hashicorp.com/terraform/cli/commands/console).

```shell
terraform console
> module.vpc.nat_gateway_attributes_by_az
{
  "us-east-2a" = {
    "allocation_id" = "eipalloc-0ae0e24ffe193f2a1"
    "association_id" = "eipassoc-0d714a2e4a1f43c46"
    "connectivity_type" = "public"
    "id" = "nat-076e272ecaff6fce0"
    "network_interface_id" = "eni-07d0d8f11fc3380b5"
    "private_ip" = "10.0.2.19"
    "public_ip" = "<>"
    "subnet_id" = "subnet-005519f1eb2ca5e9d"
    "tags" = tomap({
      "Name" = "nat-my-public-us-east-2a"
      "subnet_type" = "public"
    })
    "tags_all" = tomap({
      "Name" = "nat-my-public-us-east-2a"
      "subnet_type" = "public"
    })
  }
  "us-east-2b" = {
    "allocation_id" = "eipalloc-0a0e69ff06847b9cc"
    "association_id" = "eipassoc-00ae0cc78566f5ad9"
    "connectivity_type" = "public"
    "id" = "nat-063181ad924968f92"
    "network_interface_id" = "eni-04bc3f3eb3ac6ce77"
    "private_ip" = "10.0.3.102"
    "public_ip" = "<>"
    "subnet_id" = "subnet-04c0b573d8937853d"
    "tags" = tomap({
      "Name" = "nat-my-public-us-east-2b"
      "subnet_type" = "public"
    })
    "tags_all" = tomap({
      "Name" = "nat-my-public-us-east-2b"
      "subnet_type" = "public"
    })
  }
}
```

You can see that the vpc is in 2 AZs and since `nat_gateway_configuration = "all_azs"` nat gateways were built per AZ. The output object is a nested map and can be referenced with `.` notiation.

```hcl
> module.vpc.nat_gateway_attributes_by_az.us-east-2a.id
"nat-076e272ecaff6fce0"
> module.vpc.nat_gateway_attributes_by_az.us-east-2a.public_ip
"3.21.81.83"
```

Since it is a map you can also use expressions to grab values from each nat gateway and even construct them into another useful map:

```hcl
> { for az, attrs in module.vpc.nat_gateway_attributes_by_az: az => { id : attrs.id, private_ip : attrs.private_ip } }
{
  "us-east-2a" = {
    "id" = "nat-076e272ecaff6fce0"
    "private_ip" = "10.0.2.19"
  }
  "us-east-2b" = {
    "id" = "nat-063181ad924968f92"
    "private_ip" = "10.0.3.102"
  }
}
```

Finally, they can be passed to another resource as the parameter to `for_each`. The result would be 2 new resources who's [block label](https://developer.hashicorp.com/terraform/docs/glossary#block) corresponds to the AZ those resources are in

```hcl
resource "aws_route" "new_route_to_nat_gateway" {
  for_each = module.vpc.nat_gateway_attributes_by_az

  route_table_id         = aws_route_table.new_route_table[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = each.value.id
}
