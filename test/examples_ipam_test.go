package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesIPAM(t *testing.T) {

	ipamBase := &terraform.Options{
		TerraformDir: "./hcl_fixtures/ipam_base",
	}
	defer terraform.Destroy(t, ipamBase)
	terraform.InitAndApply(t, ipamBase)

	pool_id := terraform.Output(t, ipamBase, "pool_id")

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/ipam",
		Vars: map[string]interface{}{
			"ipam_pool_id": pool_id,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}
