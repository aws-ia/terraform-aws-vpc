# Developer Documentation

## Outputs Methodology

This module organizes outputs by creating output collections of grouped entire resources. The benefit of this is that, most likely, attributes users want access to are already present without having to create new `output {}` for each possible attribute. The [potential] downside is that you will have to extract it yourself using HCL logic. See the [outputs.tf](https://github.com/aws-ia/terraform-aws-vpc/outputs.tf) for examples.

Our naming convetion attempts to make the output content clear. `route_table_attributes_by_type_by_az` is a nested map of route table resource attributes grouped by their subnet type then by the az.  Example:
```terraform
route_table_attributes_by_type_by_az = {
  "private" = {
    "us-east-1a" = {
      "id" = "rtb-0e77040c0598df003"
      "route_table_id" = "rtb-0e77040c0598df003"
      "tags" = tolist([
        {
          "key" = "Name"
          "value" = "private-us-east-1a"
        },
      ])
      "vpc_id" = "vpc-033e054f49409592a"
    }
    "us-east-1b" = {
      ...
    }
  "public" = { ... }
```

## Adding new subnet types

*Note: All subnet types **MUST** accept both `cidrs` and `netmask` arguments.*

1. Updates to variables.tf

    1. Add new to `subnets` key variable validation:

        ```terraform
        validation {
          error_message = "Only valid key values \"public\", \"private\", or \"transit_gateway\"."
          condition = length(setsubtract(keys(var.subnets), [
            "public",
            "private",
            "transit_gateway",
            "<new type here>"
          ])) == 0
        }
        ```

    1. Specify keys allowed in new variable type map. Copy an existing one and edit the keys to match what you expect users to input:

        ```terraform
        # All var.subnets.public valid keys
        validation {
          error_message = "Invalid key in public subnets. Valid options include: \"cidrs\", \"netmask\", \"name_prefix\", \"nat_gateway_configuration\", \"tags\"."
          condition = length(setsubtract(keys(try(var.subnets.public, {})), [
              "cidrs",
              "netmask",
              "name_prefix",
              "nat_gateway_configuration",
              "tags"
          ])) == 0
        }
        ```

   1. Include in description:

      ```terraform
        **private subnet type options:**
          - All shared keys above
          - `connect_to_public_natgw`  = (Optional|bool) <>
      ```

2. Write configuration code

*Note: each for_each loop must account for if a user does not want to create the particular subnet type. Follow examples from other subnet types in main.tf*

    * Create new `aws_subnet`
    * Create new `aws_route_table`
    * Create new `aws_route_table_association`
    * Consider and create appropriate `aws_route`


3. Create appropriate outputs

    1. `output "<new subnet type>_subnet_attributes_by_az"`
    1. add new type to `route_table_attributes_by_type_by_az`
