package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesVPCLattice(t *testing.T) {
	
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/vpc_lattice",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}