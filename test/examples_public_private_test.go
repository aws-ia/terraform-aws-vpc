package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/likexian/gokit/assert"
)

func TestExamplesPublicPrivateCWLogs(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/public_private_flow_logs",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)

	publicTagsLength := terraform.Output(t, terraformOptions, "public_subnets_tags_length")
	assert.Equal(t, "2", publicTagsLength)
	privateTagsLength := terraform.Output(t, terraformOptions, "private_subnets_tags_length")
	assert.Equal(t, "1", privateTagsLength)
}

func TestExamplesPublicPrivateS3FlowLogs(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/public_private_flow_logs",
		Vars: map[string]interface{}{
			"vpc_flow_logs": map[string]interface{}{
				"log_destination_type": "s3",
				"kms_key_id":           nil,
				"desination_options": map[string]interface{}{
					"file_format": "parquet",
				},
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)
}
