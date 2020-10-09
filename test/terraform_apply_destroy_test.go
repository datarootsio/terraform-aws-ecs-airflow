package test

import (
	"testing"
	"time"

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

	terraformOptions.Vars["airflow_image_name"] = "puckel/docker-airflow"
	terraformOptions.Vars["airflow_image_tag"] = "1.10.9"
	terraformOptions.Vars["vpc_id"] = "vpc-d8170bbe"
	terraformOptions.Vars["subnet_id"] = "subnet-81b338db"
	terraformOptions.Vars["rds_instance_class"] = "db.t2.micro"

	return terraformOptions, nil
}

func TestApplyAndDestroyWithDefaultValues(t *testing.T) {
	t.Parallel()

	options, err := getDefaultTerraformOptions(t)
	assert.NoError(t, err)

	defer terraform.Destroy(t, options)
	_, err = terraform.InitAndApplyE(t, options)
	assert.NoError(t, err)
}
