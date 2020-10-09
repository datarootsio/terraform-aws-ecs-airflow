package test

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

func getDefaultTerraformOptions(t *testing.T) (*terraform.Options, error) {

	tempTestFolder := test_structure.CopyTerraformFolderToTemp(t, "..", ".")

	terraformOptions := &terraform.Options{
		TerraformDir:       tempTestFolder,
		Vars:               map[string]interface{}{},
		MaxRetries:         5,
		TimeBetweenRetries: 5 * time.Minute,
		NoColor:            true,
		Logger:             logger.TestingT,
	}

	terraformOptions.Vars["name"] = "cicd-aws"

	return terraformOptions, nil
}

func TestApplyAndDestroyWithDefaultValues(t *testing.T) {
	t.Parallel()

	options, err := getDefaultTerraformOptions(t)
	assert.NoError(t, err)

	options.Vars["extra_tag"] = "my_super_tag"

	defer terraform.Destroy(t, options)
	_, err = terraform.InitAndApplyE(t, options)
	assert.NoError(t, err)

	aws.AssertS3BucketExists(t, "eu-west-1", "cicd-aws-this-is-a-blueprint")
	bucketName := aws.FindS3BucketWithTag(t, "eu-west-1", "ExtraTag", "my_super_tag")
	assert.Equal(t, bucketName, "cicd-aws-this-is-a-blueprint")
}
