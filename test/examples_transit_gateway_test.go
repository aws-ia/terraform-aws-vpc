package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/likexian/gokit/assert"
)

func TestExamplesTransitGateway(t *testing.T) {
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/transit_gateway",
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)

	tgwTagsLength := terraform.Output(t, terraformOptions, "tgw_subnets_tags_length")
	assert.Equal(t, "2", tgwTagsLength)

	privateTagsLength := terraform.Output(t, terraformOptions, "private_subnets_tags_length")
	assert.Equal(t, "1", privateTagsLength)
}
