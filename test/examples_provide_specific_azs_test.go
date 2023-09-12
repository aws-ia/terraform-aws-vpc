package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesSpecificAzs(t *testing.T) {
	
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/provide_specific_azs",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}