package test

import (
	"context"
	"fmt"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"log"
	"os"
	"testing"
)

type testCase struct {
	name     string
	function func(*testing.T, *terraform.Options)
}

type testRegion struct {
	region  string
	profile string
}

func RunTests(t *testing.T, testRegions []testRegion, testCases []testCase, testPath string) {
	for _, testRegion := range testRegions {
		testRegion := testRegion
		t.Run(testRegion.region, func(t *testing.T) {
			t.Parallel()
			tmpPath := test_structure.CopyTerraformFolderToTemp(t, "../", testPath)
			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: tmpPath,
				Vars: map[string]interface{}{
					"region":  testRegion.region,
					"profile": testRegion.profile,
				},
			})
			if os.Getenv("TERRATEST_QUIET") == "1" {
				terraformOptions.Logger = logger.Discard
			}
			defer Destroy(t, terraformOptions)
			terraform.Init(t, terraformOptions)
			terraform.Apply(t, terraformOptions)
			for _, testCase := range testCases {
				t.Run(testCase.name, func(t *testing.T) {
					testCase.function(t, terraformOptions)
				})
			}
		})
	}
}

func Destroy(t *testing.T, terraformOptions *terraform.Options) {
	if os.Getenv("SKIP_DESTROY") != "1" {
		fmt.Printf("Running cleanup for %s %s\n", terraformOptions.Vars["region"].(string), terraformOptions.Vars["profile"].(string))
		terraform.Destroy(t, terraformOptions)
		fmt.Printf("Completed cleanup for %s %s\n", terraformOptions.Vars["region"].(string), terraformOptions.Vars["profile"].(string))
	}
}

func getEc2Client(profile string, region string) *ec2.Client {
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithSharedConfigProfile(profile), config.WithRegion(region))
	if err != nil {
		log.Fatalf("failed to load configuration, %v", err)
	}
	cfg.Region = region
	return ec2.NewFromConfig(cfg)
}
