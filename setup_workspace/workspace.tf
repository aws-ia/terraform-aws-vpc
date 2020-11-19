terraform {
  required_version = ">= 0.13.5"
}

resource "random_pet" "name" {
  prefix = "tfm-aws"
  length = 1
}

# Generate new terraform org and workspace

module "tfc_workspace" {
  source                = "aws-quickstart/tfc_workspace/aws"
  tfe_email             = var.tfe_email
  tfe_organization      = var.tfe_organization
  tfe_workspace         = var.tfe_workspace
  AWS_ACCESS_KEY_ID     = var.AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
}


output "user_instructions" {
  value = <<README
# your org name                                 = ${module.tfc_workspace.tfm-aws-org-name}
# your workspace for creating a new vpc is      = ${module.tfc_workspace.tfm-aws-workspace-name}
# caution: make sure your credential are secured ourside version control (and follow secrets mangement bestpractices)
# Run these commands in order:
#   terraform init
#then
#   terraform apply
#   or
#   terraform apply  -var-file="/Users/username/.aws/terraform.tfvars"
README
}
