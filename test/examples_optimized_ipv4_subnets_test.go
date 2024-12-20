package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/likexian/gokit/assert"
)

func TestExamplesOptimizedSubnets(t *testing.T) {
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/optimized_ipv4_subnets",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)

	privateTagsLength := terraform.Output(t, terraformOptions, "private_subnets_tags_length")
	assert.Equal(t, "1", privateTagsLength)
}
