<!-- BEGIN_TF_DOCS -->
# Adding secondary CIDRs to pre-existing VPCs

This example shows how you can use this module to apply a secondary CIDR to a pre-existing VPC.

Note: If using IPAM, you can only build 1 secondary CIDR at a time. One method to do that is to use `-target`. Using the example you would uncomment the "vpc" and "ipam\_base\_for\_example\_only" modules then:

1. terraform init
1. terraform apply -target module.vpc -target module.ipam\_base\_for\_example\_only
1. terraform apply -target module.secondary

## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_secondary"></a> [secondary](#module\_secondary) | ../.. | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../.. | n/a |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->