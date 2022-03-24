package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesPrivateOnly(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/private_only",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}
