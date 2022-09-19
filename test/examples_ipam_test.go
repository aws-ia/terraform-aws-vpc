package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesIPAM(t *testing.T) {
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/ipam",
		Vars: map[string]interface{}{
			"ipam_pool_id": "test",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)
}
