package test

import (
	"fmt"
	"github.com/aws/aws-sdk-go/service/iam"
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

	terraformOptions.Vars["airflow_image_name"] = "puckel/docker-airflow"
	terraformOptions.Vars["airflow_image_tag"] = "1.10.9"
	terraformOptions.Vars["airflow_log_region"] = "eu-west-1"
	terraformOptions.Vars["airflow_log_retention"] = "7"
	terraformOptions.Vars["airflow_navbar_color"] = "#e27d60"

	terraformOptions.Vars["ecs_cluster_name"] = "dtr-airflow-test"
	terraformOptions.Vars["ecs_cpu"] = 256
	terraformOptions.Vars["ecs_memory"] = 512

	terraformOptions.Vars["vpc_id"] = "vpc-d8170bbe"
	terraformOptions.Vars["subnet_id"] = "subnet-81b338db"

	terraformOptions.Vars["rds_instance_class"] = "db.t2.micro"

	return terraformOptions, nil
}

func TestApplyAndDestroyWithDefaultValues(t *testing.T) {
	region := "eu-west-1"

	t.Parallel()

	options, err := getDefaultTerraformOptions(t)
	assert.NoError(t, err)

	defer terraform.Destroy(t, options)
	_, err = terraform.InitAndApplyE(t, options)
	assert.NoError(t, err)

	iamClient := aws.NewIamClient(t, region)

	// check if roles exists
	rolesToCheck := []string{"airflow-task-execution-role", "airflow-task-role"}
	for _, roleName := range rolesToCheck {
		roleInput := &iam.GetRoleInput{RoleName: &roleName}
		_, err := iamClient.GetRole(roleInput)
		assert.Equal(t, err, nil)
	}

	// check if ecs cluster exists
	aws.GetEcsCluster(t, region, "dtr-airflow-test")
	airflowEcsService := aws.GetEcsService(t, region, "dtr-airflow-test", "airflow")

	for i := 0; i < 10; i++ {
		fmt.Println("*airflowEcsService.Status")
		fmt.Println(*airflowEcsService.Status)
		time.Sleep(10 * time.Second)
	}

}
