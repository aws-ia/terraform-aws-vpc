package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)


func TestExamplesNATGWRoutesNoNATGWNoRoute(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "./hcl_fixtures/nat_gw_routes",
		Vars: map[string]interface{}{
			"nat_gateway_configuration" : "none",
			"route_to_nw" : false,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)
}

func TestExamplesNATGWRoutesSingleAZNATGWNoRoute(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "./hcl_fixtures/nat_gw_routes",
		Vars: map[string]interface{}{
			"nat_gateway_configuration" : "single_az",
			"route_to_nw" : false,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)
}

func TestExamplesNATGWRoutesAllAZsNATGWNoRoute(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "./hcl_fixtures/nat_gw_routes",
		Vars: map[string]interface{}{
			"nat_gateway_configuration" : "all_azs",
			"route_to_nw" : false,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)
}

func TestExamplesNATGWRoutesSingleAZNATGWWithRoute(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "./hcl_fixtures/nat_gw_routes",
		Vars: map[string]interface{}{
			"nat_gateway_configuration" : "single_az",
			"route_to_nw" : true,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)
}

func TestExamplesNATGWRoutesAllAZsNATGWWithRoute(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "./hcl_fixtures/nat_gw_routes",
		Vars: map[string]interface{}{
			"nat_gateway_configuration" : "all_azs",
			"route_to_nw" : true,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	terraform.ApplyAndIdempotent(t, terraformOptions)
}
