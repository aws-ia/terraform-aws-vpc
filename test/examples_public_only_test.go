package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesPublicOnly(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/public_only",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}
