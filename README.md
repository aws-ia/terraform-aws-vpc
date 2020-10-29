# terraform-aws-quickstart-vpc
To deploy, do the following:
1. Sign up for [Terraform Cloud](https://app.terraform.io/signup/account). (There is a free tier available.)
2. Clone the **aws-quickstart/terraform-module-vpc** directory.
3. In the main directory (**aws-quickstart/terraform-module-vpc**), run the following commands:

        terraform login
        export TERRAFORM_CONFIG="$HOME/.terraform.d/credentials.tfrc.json"
        terrafrom init
        terrafrom apply

4. Run the following commands in the order they appear below:
   
        cd ./setup_env
        terraform init
        terraform apply
    
5. Follow the command prompts.
