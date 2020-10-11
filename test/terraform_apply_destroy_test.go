package test

import (
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/aws/aws-sdk-go/service/iam"

	"github.com/PuerkitoBio/goquery"
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
	terraformOptions.Vars["ecs_cpu"] = 1024
	terraformOptions.Vars["ecs_memory"] = 2048

	terraformOptions.Vars["vpc_id"] = "vpc-007b7377a35da621a"
	terraformOptions.Vars["public_subnet_id"] = "subnet-01fa6330ad05a409f"
	terraformOptions.Vars["backup_public_subnet_id"] = "subnet-051fd974e6b4f0db9"

	// Get password and username from env vars
	terraformOptions.Vars["rds_username"] = "dataroots"
	terraformOptions.Vars["rds_password"] = "dataroots"
	terraformOptions.Vars["rds_instance_class"] = "db.t2.micro"
	terraformOptions.Vars["rds_availability_zone"] = "eu-west-1a"
	terraformOptions.Vars["rds_deletion_protection"] = false

	return terraformOptions, nil
}

func TestApplyAndDestroyWithDefaultValues(t *testing.T) {
	// 'GLOBAL' test vars
	region := "eu-west-1"
	clusterName := "dtr-airflow-test"
	serviceName := "airflow"
	desiredStatusRunning := "RUNNING"
	retrySleepTime := time.Duration(10) * time.Second
	ecsGetTaskArnMaxRetries := 10
	ecsGetTaskStatusMaxRetries := 15

	// TODO: Check the task def rev number before and after apply and see if the rev num has increased by 1

	t.Parallel()

	options, err := getDefaultTerraformOptions(t)
	assert.NoError(t, err)

	// terraform destroy => when test completes
	defer terraform.Destroy(t, options)
	// terraform apply
	_, err = terraform.InitAndApplyE(t, options)
	assert.NoError(t, err)

	iamClient := aws.NewIamClient(t, region)

	// check if roles exists
	rolesToCheck := []string{"airflow-task-execution-role", "airflow-task-role"}
	for _, roleName := range rolesToCheck {
		roleInput := &iam.GetRoleInput{RoleName: &roleName}
		_, err := iamClient.GetRole(roleInput)
		assert.NoError(t, err)
	}

	// check if ecs cluster exists
	_, err = aws.GetEcsClusterE(t, region, clusterName)
	assert.NoError(t, err)

	// check if the service is ACTIVE
	airflowEcsService, err := aws.GetEcsServiceE(t, region, clusterName, serviceName)
	assert.NoError(t, err)
	assert.Equal(t, "ACTIVE", *airflowEcsService.Status)
	// check if there is 1 deployment namely the airflow one
	assert.Equal(t, 1, len(airflowEcsService.Deployments))

	ecsClient := aws.NewEcsClient(t, region)

	// Get all the arns of the task that are running.
	// There should only be one task running, the airflow task
	listRunningTasksInput := &ecs.ListTasksInput{
		Cluster:       &clusterName,
		ServiceName:   &serviceName,
		DesiredStatus: &desiredStatusRunning,
	}

	var taskArns []*string
	for i := 0; i < ecsGetTaskArnMaxRetries; i++ {
		runningTasks, _ := ecsClient.ListTasks(listRunningTasksInput)
		if len(runningTasks.TaskArns) == 1 {
			taskArns = runningTasks.TaskArns
			break
		}
		time.Sleep(retrySleepTime)
	}
	// Check that there is only one task running
	assert.Equal(t, 1, len(taskArns))

	// If there is no task running you can't do the following tests so skip them
	if len(taskArns) == 1 {
		describeTasksInput := &ecs.DescribeTasksInput{
			Cluster: &clusterName,
			Tasks:   taskArns,
		}

		// Wait until the airflow task is in a RUNNING state or STOPPED state
		// RUNNING => the container startup went well
		// STOPPED => the container crashed while starting up
		var taskStatus string
		for i := 0; i < ecsGetTaskStatusMaxRetries; i++ {
			describeTasks, _ := ecsClient.DescribeTasks(describeTasksInput)
			airflowTask := describeTasks.Tasks[0]

			taskStatus = *airflowTask.LastStatus
			if taskStatus == "RUNNING" || taskStatus == "STOPPED" {
				break
			}
			time.Sleep(retrySleepTime)
		}
		assert.Equal(t, "RUNNING", taskStatus)

		// TODO: Figure out why even when it is running it returns a 503
		// Solution for now is to wait for half a minute
		time.Sleep(time.Duration(30) * time.Second)

		airflowAlbDns := terraform.Output(t, options, "airflow_alb_dns")
		airflowUrl := fmt.Sprintf("http://%s", airflowAlbDns)
		// Request the HTML page.
		res, err := http.Get(airflowUrl)
		assert.NoError(t, err)

		// Check the status code
		assert.Equal(t, 200, res.StatusCode)

		// Get the actual HTML code
		defer res.Body.Close()
		doc, err := goquery.NewDocumentFromReader(res.Body)
		assert.NoError(t, err)

		// Check if the navbar has the correct color
		navbarStyle, exists := doc.Find(".navbar.navbar-inverse.navbar-fixed-top").First().Attr("style")
		assert.Equal(t, true, exists)
		assert.Equal(t, true, strings.Contains(navbarStyle, "background-color: #e27d60"))
	}
}
