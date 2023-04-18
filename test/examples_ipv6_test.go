package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesIPv6(t *testing.T) {
	
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/ipv6",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}