# Terraform AWS VPC
This module configures your Terraform organization and workspace.  
Authors: David Wright (dwright@hashicorp.com) and Tony Vattahil (tonynv@amazon.com)

# Install Terraform
To deploy this module, do the following:
Install Terraform. (See [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) for a tutorial.) 

# Configure AWS CLI 
> ~/.aws/credentials (Linux & Mac)

```
[default]
aws_access_key_id=AKIAIOSFODNN7EXAMPLE
aws_secret_access_key=wJalrXUtnSAMPLESECRETKEY
```
(See [Guide] for more info (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)

Local execution
## Clone the repo (requires git client)

> !!!!WARNING!!!!: Run these commands in order:

Clone the **aws-quickstart/terraform-aws-vpc** repository.

`git clone https://github.com/aws-quickstart/terraform-aws-vpc`

Change directory to the root directory.

`cd terraform-aws-vpc`

Initalize terrafrom module

`terraform init`

Run terraform apply

`terraform apply 

