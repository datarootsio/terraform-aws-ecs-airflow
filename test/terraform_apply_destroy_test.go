package test

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"testing"
	"time"

	"github.com/PuerkitoBio/goquery"

	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/aws/aws-sdk-go/service/iam"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	testStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

func getPublicIp() string {
	res, _ := http.Get("https://api.ipify.org")
	ip, _ := ioutil.ReadAll(res.Body)
	return string(ip)
}

func AddPreAndSuffix(resourceName string) string {
	resourcePrefix := "dataroots"
	resourceSuffix := "dev"
	return fmt.Sprintf("%s-%s-%s", resourcePrefix, resourceName, resourceSuffix)
}

func GetContainerWithName(containerName string, containers []*ecs.Container) *ecs.Container {
	for _, container := range containers {
		if *container.Name == containerName {
			return container
		}
	}
	return nil
}

func getDefaultTerraformOptions(t *testing.T) (*terraform.Options, error) {
	tempTestFolder := testStructure.CopyTerraformFolderToTemp(t, "..", ".")

	terraformOptions := &terraform.Options{
		TerraformDir:       tempTestFolder,
		Vars:               map[string]interface{}{},
		MaxRetries:         5,
		TimeBetweenRetries: 5 * time.Minute,
		NoColor:            true,
		Logger:             logger.TestingT,
	}

	terraformOptions.Vars["resource_prefix"] = "dataroots"
	terraformOptions.Vars["resource_suffix"] = "dev"
	terraformOptions.Vars["extra_tags"] = map[string]interface{}{
		"ATestTag": "a_test_tag",
	}

	terraformOptions.Vars["airflow_image_name"] = "apache/airflow"
	terraformOptions.Vars["airflow_image_tag"] = "1.10.12"
	terraformOptions.Vars["airflow_log_region"] = "eu-west-1"
	terraformOptions.Vars["airflow_log_retention"] = "7"
	terraformOptions.Vars["airflow_navbar_color"] = "#e27d60"

	terraformOptions.Vars["ecs_cpu"] = 1024
	terraformOptions.Vars["ecs_memory"] = 2048

	terraformOptions.Vars["ip_allow_list"] = []string{
		fmt.Sprintf("%s/32", getPublicIp()),
	}
	terraformOptions.Vars["vpc_id"] = "vpc-0eafa6867cb3bdaa3"
	terraformOptions.Vars["public_subnet_id"] = "subnet-08da686d46e99872d"
	terraformOptions.Vars["backup_public_subnet_id"] = "subnet-0e5bb83f963f8df0f"
	terraformOptions.Vars["private_subnet_id"] = "subnet-03c2a3885cfc8a740"
	terraformOptions.Vars["backup_private_subnet_id"] = "subnet-09c0ce0aff676904a"

	// Get password and username from env vars
	terraformOptions.Vars["postgres_uri"] = ""
	terraformOptions.Vars["rds_username"] = "dataroots"
	terraformOptions.Vars["rds_password"] = "dataroots"
	terraformOptions.Vars["rds_instance_class"] = "db.t2.micro"
	terraformOptions.Vars["rds_availability_zone"] = "eu-west-1a"
	terraformOptions.Vars["rds_deletion_protection"] = false

	return terraformOptions, nil
}

func TestApplyAndDestroyWithDefaultValues(t *testing.T) {
	fmt.Println("Starting test")
	// 'GLOBAL' test vars
	region := "eu-west-1"
	clusterName := AddPreAndSuffix("airflow")
	serviceName := AddPreAndSuffix("airflow")
	webserverContainerName := AddPreAndSuffix("airflow-webserver")
	schedulerContainerName := AddPreAndSuffix("airflow-webserver")
	sidecarContainerName := AddPreAndSuffix("airflow-sidecar")
	desiredStatusRunning := "RUNNING"
	retrySleepTime := time.Duration(10) * time.Second
	ecsGetTaskArnMaxRetries := 10
	ecsGetTaskStatusMaxRetries := 15
	httpStatusCodeMaxRetries := 18
	amountOfConsecutiveGetsToBeHealthy := 6

	// TODO: Check the task def rev number before and after apply and see if the rev num has increased by 1

	t.Parallel()

	options, err := getDefaultTerraformOptions(t)
	assert.NoError(t, err)

	// terraform destroy => when test completes
	defer terraform.Destroy(t, options)
	fmt.Println("Running: terraform init && terraform apply")
	_, err = terraform.InitAndApplyE(t, options)
	assert.NoError(t, err)

	// if there are terraform errors, do nothing
	if err == nil {
		fmt.Println("Terraform apply returned no error, continuing")
		iamClient := aws.NewIamClient(t, region)

		fmt.Println("Checking if roles exists")
		rolesToCheck := []string{
			AddPreAndSuffix("airflow-task-execution-role"),
			AddPreAndSuffix("airflow-task-role"),
		}
		for _, roleName := range rolesToCheck {
			roleInput := &iam.GetRoleInput{RoleName: &roleName}
			_, err := iamClient.GetRole(roleInput)
			assert.NoError(t, err)
		}

		fmt.Println("Checking if ecs cluster exists")
		_, err = aws.GetEcsClusterE(t, region, clusterName)
		assert.NoError(t, err)

		fmt.Println("Checking if the service is ACTIVE")
		airflowEcsService, err := aws.GetEcsServiceE(t, region, clusterName, serviceName)
		assert.NoError(t, err)
		assert.Equal(t, "ACTIVE", *airflowEcsService.Status)

		fmt.Println("Checking if there is 1 deployment namely the airflow one")
		assert.Equal(t, 1, len(airflowEcsService.Deployments))

		ecsClient := aws.NewEcsClient(t, region)

		// Get all the arns of the task that are running.
		// There should only be one task running, the airflow task
		fmt.Println("Getting task arns")
		listRunningTasksInput := &ecs.ListTasksInput{
			Cluster:       &clusterName,
			ServiceName:   &serviceName,
			DesiredStatus: &desiredStatusRunning,
		}

		var taskArns []*string
		for i := 0; i < ecsGetTaskArnMaxRetries; i++ {
			fmt.Printf("Getting task arns, try... %d\n", i)

			runningTasks, _ := ecsClient.ListTasks(listRunningTasksInput)
			if len(runningTasks.TaskArns) == 1 {
				taskArns = runningTasks.TaskArns
				break
			}
			time.Sleep(retrySleepTime)
		}
		fmt.Println("Getting that there is only one task running")
		assert.Equal(t, 1, len(taskArns))

		// If there is no task running you can't do the following tests so skip them
		if len(taskArns) == 1 {
			fmt.Println("Task is running, continuing")
			describeTasksInput := &ecs.DescribeTasksInput{
				Cluster: &clusterName,
				Tasks:   taskArns,
			}

			// Wait until the 3 containers are in there desired state
			// - Sidecar container must be STOPPED to be healthy
			//   (only runs once and then stops it's an "init container")
			// - Webserver container must be RUNNING to be healthy
			// - Scheduler container must be RUNNING to be healthy
			fmt.Println("Getting container statuses")
			var webserverContainer ecs.Container
			var schedulerContainer ecs.Container
			var sidecarContainer ecs.Container
			for i := 0; i < ecsGetTaskStatusMaxRetries; i++ {
				fmt.Printf("Getting container statuses, try... %d\n", i)

				describeTasks, _ := ecsClient.DescribeTasks(describeTasksInput)
				airflowTask := describeTasks.Tasks[0]
				containers := airflowTask.Containers

				webserverContainer = *GetContainerWithName(webserverContainerName, containers)
				schedulerContainer = *GetContainerWithName(schedulerContainerName, containers)
				sidecarContainer = *GetContainerWithName(sidecarContainerName, containers)

				if *webserverContainer.LastStatus == "RUNNING" &&
					*schedulerContainer.LastStatus == "RUNNING" &&
					*sidecarContainer.LastStatus == "STOPPED" {
					break
				}
				time.Sleep(retrySleepTime)
			}
			assert.Equal(t, "RUNNING", *webserverContainer.LastStatus)
			assert.Equal(t, "RUNNING", *schedulerContainer.LastStatus)
			assert.Equal(t, "STOPPED", *sidecarContainer.LastStatus)

			// We do consecutive checks because sometime it could be that
			// the webserver is available for a short amount of time and crashes
			// a couple of seconds later
			fmt.Println("Doing HTTP request/checking health")
			airflowAlbDNS := terraform.Output(t, options, "airflow_alb_dns")
			airflowURL := fmt.Sprintf("http://%s", airflowAlbDNS)

			var amountOfConsecutiveHealthyChecks int
			var res *http.Response
			for i := 0; i < httpStatusCodeMaxRetries; i++ {
				fmt.Printf("Doing HTTP request to airflow webservice, try... %d\n", i)
				res, err = http.Get(airflowURL)
				if res != nil && err == nil {
					if res.StatusCode == 200 {
						amountOfConsecutiveHealthyChecks++
						fmt.Println("Webservice is healthy")
					} else {
						amountOfConsecutiveHealthyChecks = 0
						fmt.Println("Webservice is NOT healthy")
					}

					if amountOfConsecutiveHealthyChecks == amountOfConsecutiveGetsToBeHealthy {
						break
					}
				}
				time.Sleep(retrySleepTime)
			}

			if res != nil {
				assert.Equal(t, 200, res.StatusCode)
				assert.Equal(t, amountOfConsecutiveGetsToBeHealthy, amountOfConsecutiveHealthyChecks)

				if res.StatusCode == 200 {
					fmt.Println("Getting the actual HTML code")
					defer res.Body.Close()
					doc, err := goquery.NewDocumentFromReader(res.Body)
					assert.NoError(t, err)

					fmt.Println("Checking if the navbar has the correct color")
					navbarStyle, exists := doc.Find(".navbar.navbar-inverse.navbar-fixed-top").First().Attr("style")
					assert.Equal(t, true, exists)
					assert.Contains(t, navbarStyle, "background-color: #e27d60")
				}
			}
		}
	}
}
