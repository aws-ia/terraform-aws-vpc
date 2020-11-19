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


resource "null_resource" "setup_backend_file" {
  depends_on = [module.tfc_workspace]
  provisioner "local-exec" {
    command = "mv backend.hcl ../deploy_demo"
  }
}


resource "null_resource" "remote_init" {
  depends_on = [null_resource.setup_backend_file]
  provisioner "local-exec" {
    working_dir = "../deploy_demo"
    command     = "terraform init -backend-config=backend.hcl"
  }
}

output "user_instructions" {
  value = <<README
# org name    = ${module.tfc_workspace.tfm-aws-org-name}
# workspace   = ${module.tfc_workspace.tfm-aws-workspace-name}
#
#
# Run these commands in order:
   cd ../deploy_demo

# Configure your tfvars file
  AWS_SECRET_ACCESS_KEY = "*****************"
  AWS_ACCESS_KEY_ID     = "*****************"

# !!!!CAUTION!!!!: Make sure your credential are secured ourside version control (and follow secrets mangement bestpractices)
#   
   terraform apply  -var-file="/Users/username/.aws/terraform.tfvars"
README
}
