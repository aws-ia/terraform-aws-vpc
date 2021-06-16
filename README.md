# Terraform AWS VPC
This module is designed to deploy into Terraform Cloud
Authors: David Wright (dwright@hashicorp.com) and Tony Vattahil (tonynv@amazon.com)


# Install Terraform
To deploy this module, do the following:
Install Terraform. (See [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) for a tutorial.) 

# Sign up for Terraform Cloud
Sign up and log into [Terraform Cloud](https://app.terraform.io/signup/account). (There is a free tier available.)

## Configure Terraform Cloud API Access

Generate terraform cloud token

`terraform login` 

Export TERRAFORM_CONFIG

`export TERRAFORM_CONFIG="$HOME/.terraform.d/credentials.tfrc.json"`

# Configure your tfvars file

_Example filepath_ = `$HOME/.aws/terraform.tfvars`

_Example tfvars file contents_ 

```
AWS_SECRET_ACCESS_KEY = "*****************"
AWS_ACCESS_KEY_ID = "*****************"
AWS_SESSION_TOKEN = "*****************"
```
> (replace *** with AKEY and SKEY)

Note: STS-based credentials _are optional_ but *highly recommended*. 

> !!!!CAUTION!!!!: Make sure your credential are secured ourside version control (and follow secrets mangement bestpractices)

# Deploy this module (instruction for linux or mac)

Clone the aws-ia/terraform-aws-vpc repository.

git clone https://github.com/aws-ia/terraform-aws-vpc

Change directory to the root directory.

cd terraform-aws-vpc/

Change to deploy directory

`cd setup_workspace`. 


Run to following commands in order:

`terraform init`

`terraform apply`  or `terraform apply  -var-file="$HOME/.aws/terraform.tfvars"`.

Change directory to deploy dir (previous command auto generates backend.hcl)

`cd ../deploy`

`terraform apply` or `terraform apply  -var-file="$HOME/.aws/terraform.tfvars"`. 

Terraform apply is run remotely in Terraform Cloud 



