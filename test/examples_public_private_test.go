package test

import (
	"testing"
	"github.com/stretchr/testify/assert"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExamplesPublicPrivateFlowLogs(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/public_private_flow_logs",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)

	log_name := terraform.Output(t, terraformOptions, "log_name")
	assert.Contains(t, "test", log_name)
	publicTagsLength := terraform.Output(t, terraformOptions, "public_subnets_tags_length")
	assert.Equal(t, "2", publicTagsLength)
	privateTagsLength := terraform.Output(t, terraformOptions, "private_subnets_tags_length")
	assert.Equal(t, "1", privateTagsLength)
}