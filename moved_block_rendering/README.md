# Notice

These files were used for the v2->v3 upgrade. Please disregard

# Moved Resources

While upgrading this module to allow for multiple private subnets, we had to adjust how we name private subnet related resources. To ease user pain we created the moved.tf file which creates corresponding entries for each private resource. However, we were unable to update `aws_route.private_to_tgw` because we used the user provided CIDR in the key. If you see a `CREATE/DELETE` for these resources you can either allow TF to force create the new routes (momentary blip in traffic) or you can manully update the name, example below:

If you see a message in your plan like this:

> module.vpc.aws_route.private_to_tgw["us-east-1a:10.0.0.0/8"] -> ["private/us-east-1a"]

Resolve with this command per AZ
```shell
terraform state mv 'module.vpc.aws_route.private_to_tgw["us-east-1a:10.0.0.0/8"]' 'module.vpc.aws_route.private_to_tgw["private/us-east-1a"]'
```

If for some reason, you want to adusted the moved.tf file to accomplish the state mv commands for you, or move other resources, the python used to generate moved.tf can be found in [moved_block_rendering/](https://github.com/aws-ia/terraform-aws-vpc/tree/main/moved_block_rendering)
