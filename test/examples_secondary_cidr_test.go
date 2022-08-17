package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesSecondaryCidr(t *testing.T) {

	primary := &terraform.Options{
		TerraformDir: "./hcl_fixtures/secondary_cidr_base",
	}
	defer terraform.Destroy(t, primary)
	terraform.InitAndApply(t, primary)

	// region := terraform.Output(t, primary, "region")
	vpcId := terraform.Output(t, primary, "vpc_id")
	natgwId1 := terraform.Output(t, primary, "natgw_id_1")
	natgwId2 := terraform.Output(t, primary, "natgw_id_2")

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/secondary_cidr",
		Vars: map[string]interface{}{
			"vpc_id":     vpcId,
			"natgw_id_1": natgwId1,
			"natgw_id_2": natgwId2,
			// "natgw_attrs": map[string]interface{}{
			// 	fmt.Sprintf("%v%v", region, "a"): natgwId1,
			// 	fmt.Sprintf("%v%v", region, "b"): natgwId2,
			// },
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)

}
