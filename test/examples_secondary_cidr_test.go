package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesSecondaryCidrAllAzs(t *testing.T) {

	primary := &terraform.Options{
		TerraformDir: "./hcl_fixtures/secondary_cidr_base",
	}
	defer terraform.Destroy(t, primary)
	terraform.InitAndApply(t, primary)

	vpcId := terraform.Output(t, primary, "vpc_id")

	natIdsOutput := terraform.OutputMapOfObjects(t, primary, "natgw_ids")

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/secondary_cidr",
		Vars: map[string]interface{}{
			"vpc_id":          vpcId,
			"natgw_id_per_az": natIdsOutput,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)

}

func TestExamplesSecondaryCidrSingleAz(t *testing.T) {

	primary := &terraform.Options{
		TerraformDir: "./hcl_fixtures/secondary_cidr_base",
		Vars: map[string]interface{}{
			"nat_gw_configuration": "single_az",
		},
	}
	defer terraform.Destroy(t, primary)
	terraform.InitAndApply(t, primary)

	vpcId := terraform.Output(t, primary, "vpc_id")

	natIdsOutput := terraform.OutputMapOfObjects(t, primary, "natgw_ids")

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/secondary_cidr",
		Vars: map[string]interface{}{
			"vpc_id":          vpcId,
			"natgw_id_per_az": natIdsOutput,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)

}
