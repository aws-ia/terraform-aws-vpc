package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/likexian/gokit/assert"
)

func TestExamplesPublicPrivate(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/public_private_flow_logs",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)

	publicTagsLength := terraform.Output(t, terraformOptions, "public_subnets_tags_length")
	assert.Equal(t, "3", publicTagsLength)
	privateTagsLength := terraform.Output(t, terraformOptions, "private_subnets_tags_length")
	assert.Equal(t, "2", privateTagsLength)
}
