# terraform-aws-vpc (Developer Preview)
Authors: David Wright (dwright@hashicorp.com) and Tony Vattahil (tonynv@amazon.com)  

To deploy this module, do the following:
1. Sign up for [Terraform Cloud](https://app.terraform.io/signup/account). (There is a free tier available.)
2. Clone this **aws-quickstart/terraform-aws-vpc** directory.

        git clone https://github.com/aws-quickstart/terraform-aws-vpc.git

3. Change directory to the root directory.

        cd terraform-aws-vpc

4. Run `terraform login` to ensure you are authenticated into Terraform Cloud.
5. Run `export TERRAFORM_CONFIG="$HOME/.terraform.d/credentials.tfrc.json"`.
6. Change directory by running `cd ./setup_workspace`.
7. Run `terraform init`.
8. Run `terraform apply`.
