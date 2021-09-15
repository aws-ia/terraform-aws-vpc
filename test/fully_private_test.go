package test

import (
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"testing"
)

// Required module author inputs are testPath and testRegions, testCases and their associated functions are optional
var testPathFullyPrivate = "modules/vpc/examples/fully_private"

var testRegionsFullyPrivate = []map[string]interface{}{
	{"region": "eu-west-3", "profile": "default"},
	{"region": "eu-south-1", "profile": "default", "create_nat_gateways_private_a": true, "create_nat_gateways_private_b": true},
}

var testCasesFullyPrivate = []testCase{
	{name: "validate no NAT/IGW were created", function: validateFullyPrivate},
}

var testRegionsIgwOnly = []map[string]interface{}{
	{"region": "eu-south-1", "profile": "default", "create_igw": true},
}

var testCasesIgwOnly = []testCase{
	{name: "validate no NAT GW were created", function: validateIgwOnly},
}

var testRegionsNatB = []map[string]interface{}{
	{"region": "eu-west-1", "profile": "default", "create_igw": true, "create_nat_gateways_private_b": true},
}

var testCasesNatB = []testCase{
	{name: "validate no NAT GW were created for private_a subnets", function: validateNatB},
}

var testRegionsNatA = []map[string]interface{}{
	{"region": "eu-west-1", "profile": "default", "create_igw": true, "create_nat_gateways_private_a": true},
}

var testCasesNatA = []testCase{
	{name: "validate no NAT GW were created for private_a subnets", function: validateNatA},
}

func validateFullyPrivate(t *testing.T, tfOpts *terraform.Options) {
	IgwId := terraform.Output(t, tfOpts, "igw_id")
	NatIds := terraform.OutputList(t, tfOpts, "nat_gw_ids")
	NatRoutesA := terraform.OutputList(t, tfOpts, "private_a_nat_routes")
	NatRoutesB := terraform.OutputList(t, tfOpts, "private_b_nat_routes")
	assert.Equal(t, "", IgwId, "there should be no IGW's created")
	assert.Equal(t, 0, len(NatIds), "there should be no NAT gateway's created")
	assert.Equal(t, 0, len(NatRoutesA), "there should be no NAT gateway's routed to private_a subnets")
	assert.Equal(t, 0, len(NatRoutesB), "there should be no NAT gateway's routed to private_b subnets")
}

func validateIgwOnly(t *testing.T, tfOpts *terraform.Options) {
	IgwId := terraform.Output(t, tfOpts, "igw_id")
	NatIds := terraform.OutputList(t, tfOpts, "nat_gw_ids")
	NatRoutesA := terraform.OutputList(t, tfOpts, "private_a_nat_routes")
	NatRoutesB := terraform.OutputList(t, tfOpts, "private_b_nat_routes")
	assert.NotEqual(t, "", IgwId, "there should be an IGW created")
	assert.Equal(t, 0, len(NatIds), "there should be no NAT gateway's created")
	assert.Equal(t, 0, len(NatRoutesA), "there should be no NAT gateway's routed to private_a subnets")
	assert.Equal(t, 0, len(NatRoutesB), "there should be no NAT gateway's routed to private_b subnets")
}

func validateNatB(t *testing.T, tfOpts *terraform.Options) {
	IgwId := terraform.Output(t, tfOpts, "igw_id")
	NatIds := terraform.OutputList(t, tfOpts, "nat_gw_ids")
	NatRoutesA := terraform.OutputList(t, tfOpts, "private_a_nat_routes")
	NatRoutesB := terraform.OutputList(t, tfOpts, "private_b_nat_routes")
	assert.NotEqual(t, "", IgwId, "there should be an IGW created")
	assert.Equal(t, 3, len(NatIds), "there should be 3 NAT gateway's created")
	assert.Equal(t, 0, len(NatRoutesA), "there should be no NAT gateway's routed to private_a subnets")
	assert.Equal(t, 3, len(NatRoutesB), "there should be 3 NAT gateway's routed to private_b subnets")
}

func validateNatA(t *testing.T, tfOpts *terraform.Options) {
	IgwId := terraform.Output(t, tfOpts, "igw_id")
	NatIds := terraform.OutputList(t, tfOpts, "nat_gw_ids")
	NatRoutesA := terraform.OutputList(t, tfOpts, "private_a_nat_routes")
	NatRoutesB := terraform.OutputList(t, tfOpts, "private_b_nat_routes")
	assert.NotEqual(t, "", IgwId, "there should be an IGW created")
	assert.Equal(t, 3, len(NatIds), "there should be 3 NAT gateway's created")
	assert.Equal(t, 3, len(NatRoutesA), "there should be 3 NAT gateway's routed to private_a subnets")
	assert.Equal(t, 0, len(NatRoutesB), "there should be no NAT gateway's routed to private_b subnets")
}

func TestFullyPrivate(t *testing.T) {
	t.Parallel()
	RunTests(t, testRegionsFullyPrivate, testCasesFullyPrivate, testPathFullyPrivate)
}

func TestPrivateA(t *testing.T) {
	t.Parallel()
	RunTests(t, testRegionsNatA, testCasesNatA, testPathFullyPrivate)
}

func TestPrivateB(t *testing.T) {
	t.Parallel()
	RunTests(t, testRegionsNatB, testCasesNatB, testPathFullyPrivate)
}

func TestIgwOnly(t *testing.T) {
	t.Parallel()
	RunTests(t, testRegionsIgwOnly, testCasesIgwOnly, testPathFullyPrivate)
}
