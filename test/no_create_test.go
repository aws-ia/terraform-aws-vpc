package test

import (
	"encoding/json"
	"fmt"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"testing"
)

// Required module author inputs are testPath and testRegions, testCases and their associated functions are optional
var testPathNoCreate = "examples/no_create"

var testVarsNoCreate = []map[string]interface{}{
	{"region": "eu-west-2", "profile": "default"},
	{"region": "eu-central-1", "profile": "default"},
}

var testCasesNoCreate = []testCase{
	{name: "validate no resources were created", function: validateNoResources},
}

func validateNoResources(t *testing.T, tfOpts *terraform.Options) {
	show := terraform.Show(t, tfOpts)
	var showData map[string]interface{}
	err := json.Unmarshal([]byte(show), &showData)
	assert.Nil(t, err, "failed to unmarshal data from terraform show")
	modules := showData["values"].(map[string]interface{})["root_module"].(map[string]interface{})["child_modules"].([]interface{})
	for _, module := range modules {
		address := module.(map[string]interface{})["address"].(string)
		if address != "module.aws-ia_vpc" {
			fmt.Printf("ignoring module %s", address)
			continue
		}
		resources := module.(map[string]interface{})["resources"].([]interface{})
		for _, resource := range resources {
			assert.Equal(
				t,
				resource.(map[string]interface{})["mode"].(string),
				"data",
				"only data mode resources should be present")
		}
	}
}

func TestNoCreate(t *testing.T) {
	t.Parallel()
	RunTests(t, testVarsNoCreate, testCasesNoCreate, testPathNoCreate)
}
