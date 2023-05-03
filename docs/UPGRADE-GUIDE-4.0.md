# Upgrade from version 3 to version 4

This VPC module is being upgraded to center all its resources on a single provider. Previously we used the awscc provider for various exploration reasons. However, as the module's usage grows, we wish to place more emphasis on customer experience and using a single provider is more seamless. Unfortunately, replacing the awscc resources requires state manipulation which is detailed below.

## Preparation for upgrade

1. create a backup of your `tfstate` file. You will have to adjust your backup mechanism to your specific situation. 1 example of backup: `tf state pull | tee tfstateV3.bak`
1. create a file of resources that require modification: `terraform state list | grep -e awscc | tee resources_to_replace.txt`

## Upgrade procedure

Switching resource types is not possible via the native `moved {}` block. For new resources types we must remove and import back the statefile.

### Overview

1. relocate any `var.tags` entries to [default_tags](https://www.hashicorp.com/blog/default-tags-in-the-terraform-aws-provider)
1. swap `awscc_ec2_route_table` for `aws_route_table` resource via `terraform state` commands
1. swap `awscc_ec2_subnet_route_table_association` for `aws_route_table_association` resource via `terraform state` commands
1. Verify no unintended changes via `terraform plan`

You can always fallback to prior state using the backup you created.

### route_table

For each `awscc_ec2_route_table` type, run the following 3 commands, replacing the relevant parts for command 3

1. Show state values: `terraform state show 'module.vpc.awscc_ec2_route_table.private["private/us-east-1a"]'`
1. Remove from state: `terraform state rm 'module.vpc.awscc_ec2_route_table.private["private/us-east-1a"]'`
1. Import as `aws` resource: `terraform import 'module.vpc.aws_route_table.private["private/us-east-1a"]' rtb-0b9b71f291529d9fe`

For command 3 you need to use the ID outputted from command 1 and you need to change `awscc_ec2_route_table` to `aws_route_table`.


### route_table_association

For each `awscc_ec2_subnet_route_table_association` type, run the following 3 commands, replacing the relevant parts for command 3

1. Show state values:
```
terraform state show 'module.vpc.awscc_ec2_subnet_route_table_association.private["private/us-east-1a"]'
resource "awscc_ec2_subnet_route_table_association" "private" {
    id             = "rtbassoc-0c65299161472413c"
    route_table_id = "rtb-0b9b71f291529d9fe"
    subnet_id      = "subnet-0e1c7e5f9d727fdc1"
}
```
2. Remove from state: `terraform state rm 'module.vpc.awscc_ec2_subnet_route_table_association.private["private/us-east-1a"]'`

3. Import as `aws` resource: `terraform import 'module.vpc.aws_route_table_association.private["private/us-east-1a"]' subnet-0e1c7e5f9d727fdc1/rtb-0b9b71f291529d9fe`

For command 3 you need to use the IDs outputted (format is `subnet_id`/`route_table_id`) from command 1 and you need to change `awscc_ec2_route_table` to `aws_route_table`.
