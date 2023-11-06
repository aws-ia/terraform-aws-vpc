data "aws_region" "current" {}

module "ipam" {
  source  = "aws-ia/ipam/aws"
  version = ">= 2.0.0"

  top_cidr = ["172.0.0.0/8"]

  pool_configurations = {
    (data.aws_region.current.name) = {
      description = "${data.aws_region.current.name} top level pool"
      cidr        = ["172.2.0.0/16"]
      locale      = data.aws_region.current.name
    }
  }
}
