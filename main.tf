###########
# Defaults
##########
terraform {
  required_version = ">= 0.13"

}

resource "random_pet" "name" {
  prefix = "aws-quickstart"
  length = 1
}

resource "tfe_organization" "quickstart-org" {
  name  = random_pet.name.id
  email = "admin@your-company.com"
}

resource "tfe_workspace" "quickstart-workspace" {
  name         = "${random_pet.name.id}-workspace"
  organization = tfe_organization.quickstart-org.name
}

output "To_create_backend_file" {
  value = <<README

# Run these commands in order:
#
# 1. terraform output | cut -d '=' -f 2 >> ./VPC/backend.hcl.json
#
# Then to create your VPC run these commands:
#
# 2. cd ./VPC
# 3. terraform init -backend-config=backend.hcl.json
$ 4. apply your AWS key and Secrets key to the terraform workspace created in step 1
# 5. terraform apply to deploy your VPC
{
  "workspaces": [
    {
      "name": "${tfe_workspace.quickstart-workspace.name}"
    }
  ],
  "hostname": "app.terraform.io",
  "organization": "${tfe_organization.quickstart-org.name}"
}
README
}
