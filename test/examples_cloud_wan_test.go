package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesCloudWAN(t *testing.T) {
	
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/cloud_wan",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}