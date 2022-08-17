package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/likexian/gokit/assert"
)

func TestExamplesTransitGateway(t *testing.T) {

	tgwBase := &terraform.Options{
		TerraformDir: "./hcl_fixtures/transit_gateway_base",
	}

	defer terraform.Destroy(t, tgwBase)
	terraform.InitAndApply(t, tgwBase)

	tgw_id := terraform.Output(t, tgwBase, "tgw_id")
	pl_id := terraform.Output(t, tgwBase, "prefix_list_id")

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/transit_gateway",
		Vars: map[string]interface{}{
			"tgw_id":         tgw_id,
			"prefix_list_id": pl_id,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)

	tgwTagsLength := terraform.Output(t, terraformOptions, "tgw_subnets_tags_length")
	assert.Equal(t, "2", tgwTagsLength)

	privateTagsLength := terraform.Output(t, terraformOptions, "private_subnets_tags_length")
	assert.Equal(t, "1", privateTagsLength)
}
