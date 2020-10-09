package test

import (
	"github.com/aws/aws-sdk-go/service/ecs"
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
	// 'GLOBAL' test vars
	region := "eu-west-1"
	clusterName := "dtr-airflow-test"
	serviceName := "airflow"
	desiredStatusRunning := "RUNNING"
	ecsGetTaskArnMaxRetries := 10
	ecsGetTaskStatusMaxRetries := 10

	// TODO: Check the task def rev number before and after apply and see if the rev num has increased by 1

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
		assert.Equal(t, nil, err)
	}

	// check if ecs cluster exists
	aws.GetEcsCluster(t, region, clusterName)

	// check if the service is ACTIVE
	airflowEcsService := aws.GetEcsService(t, region, clusterName, serviceName)
	assert.Equal(t, *airflowEcsService.Status, "ACTIVE")
	// check if there is 1 deployment namely the airflow one
	assert.Equal(t, 1, len(airflowEcsService.Deployments))

	ecsClient := aws.NewEcsClient(t, region)
	listRunningTasksInput := &ecs.ListTasksInput{
		Cluster:       &clusterName,
		ServiceName:   &serviceName,
		DesiredStatus: &desiredStatusRunning,
	}

	// Wait until the airflow task is in a RUNNING state
	var taskArns []*string
	for i := 0; i < ecsGetTaskArnMaxRetries; i++ {
		runningTasks, _ := ecsClient.ListTasks(listRunningTasksInput)
		if len(runningTasks.TaskArns) == 1 {
			taskArns = runningTasks.TaskArns
			break
		}
		time.Sleep(10 * time.Second)
	}
	assert.Equal(t, 1, len(taskArns))

	if len(taskArns) == 1{
		describeTasksInput := &ecs.DescribeTasksInput{
			Cluster: &clusterName,
			Tasks:   taskArns,
		}

		var taskStatus string
		for i := 0; i < ecsGetTaskStatusMaxRetries; i++ {
			describeTasks, _ := ecsClient.DescribeTasks(describeTasksInput)
			airflowTask := describeTasks.Tasks[0]

			taskStatus = *airflowTask.LastStatus
			if taskStatus == "RUNNING" || taskStatus == "STOPPED"{
				break
			}
			time.Sleep(10 * time.Second)
		}
		assert.Equal(t, "RUNNING", taskStatus)
	}
}
