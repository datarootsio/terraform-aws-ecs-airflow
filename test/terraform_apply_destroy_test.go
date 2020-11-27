package test

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/PuerkitoBio/goquery"

	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/aws/aws-sdk-go/service/iam"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	testStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

func AddPreAndSuffix(resourceName string, resourcePrefix string, resourceSuffix string) string {
	if resourcePrefix == "" {
		resourcePrefix = "dataroots"
	}
	if resourceSuffix == "" {
		resourceSuffix = "dev"
	}
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

func validateCluster(t *testing.T, options *terraform.Options, region string, resourcePrefix string, resourceSuffix string) {
	retrySleepTime := time.Duration(10) * time.Second
	ecsGetTaskArnMaxRetries := 20
	ecsGetTaskStatusMaxRetries := 50
	httpStatusCodeMaxRetries := 15
	amountOfConsecutiveGetsToBeHealthy := 3
	desiredStatusRunning := "RUNNING"
	clusterName := AddPreAndSuffix("airflow", resourcePrefix, resourceSuffix)
	serviceName := AddPreAndSuffix("airflow", resourcePrefix, resourceSuffix)
	webserverContainerName := AddPreAndSuffix("airflow-webserver", resourcePrefix, resourceSuffix)
	schedulerContainerName := AddPreAndSuffix("airflow-webserver", resourcePrefix, resourceSuffix)
	sidecarContainerName := AddPreAndSuffix("airflow-sidecar", resourcePrefix, resourceSuffix)

	expectedNavbarColor := "#e27d60"

	iamClient := aws.NewIamClient(t, region)

	fmt.Println("Checking if roles exists")
	rolesToCheck := []string{
		AddPreAndSuffix("airflow-task-execution-role", resourcePrefix, resourceSuffix),
		AddPreAndSuffix("airflow-task-role", resourcePrefix, resourceSuffix),
	}
	for _, roleName := range rolesToCheck {
		roleInput := &iam.GetRoleInput{RoleName: &roleName}
		_, err := iamClient.GetRole(roleInput)
		assert.NoError(t, err)
	}

	fmt.Println("Checking if ecs cluster exists")
	_, err := aws.GetEcsClusterE(t, region, clusterName)
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

		protocol := "https"
		airflowAlbDNS := terraform.Output(t, options, "airflow_dns_record")

		if options.Vars["use_https"] == false {
			protocol = "http"
		}

		if options.Vars["route53_zone_name"] == "" {
			airflowAlbDNS = terraform.Output(t, options, "airflow_alb_dns")
		}
		airflowURL := fmt.Sprintf("%s://%s", protocol, airflowAlbDNS)

		var amountOfConsecutiveHealthyChecks int
		var res *http.Response
		for i := 0; i < httpStatusCodeMaxRetries; i++ {
			fmt.Printf("Doing HTTP request to airflow webservice, try... %d\n", i)
			res, err = http.Get(airflowURL)
			if res != nil && err == nil {
				fmt.Println(res.StatusCode)
				if res.StatusCode >= 200 && res.StatusCode < 400 {
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
			assert.Equal(t, true, res.StatusCode >= 200 && res.StatusCode < 400)
			assert.Equal(t, amountOfConsecutiveGetsToBeHealthy, amountOfConsecutiveHealthyChecks)

			if res.StatusCode >= 200 && res.StatusCode < 400 {
				fmt.Println("Getting the actual HTML code")
				defer res.Body.Close()
				doc, err := goquery.NewDocumentFromReader(res.Body)
				assert.NoError(t, err)

				fmt.Println("Checking if the navbar has the correct color")
				navbarStyle, exists := doc.Find(".navbar.navbar-inverse.navbar-fixed-top").First().Attr("style")
				assert.Equal(t, true, exists)
				assert.Contains(t, navbarStyle, fmt.Sprintf("background-color: %s", expectedNavbarColor))

				// if rbac is enabled check if you can log in
				// this is to prevent 'issue #9' of happening again
				// ref: https://github.com/datarootsio/terraform-aws-ecs-airflow/issues/9
				if options.Vars["airflow_authentication"] == "rbac" {
					loginToAirflow(t, airflowAlbDNS)
				}
			}
		}
	}
}

func loginToAirflow(t *testing.T, airflowAlbDNS string) {
	username := "admin"
	password := "admin"
	airflowLoginURL := fmt.Sprintf("%s/login/", airflowAlbDNS)

	// we create a client/session to persist some headers
	// throughout the calls that we do
	jar, _ := cookiejar.New(nil)
	client := &http.Client{
		Jar: jar,
	}

	// get the page to fill in some headers in the http session
	// and to parse out the csrfToken
	res, err := client.Get(airflowLoginURL)
	assert.NoError(t, err)
	assert.Equal(t, true, res.StatusCode >= 200 && res.StatusCode < 400)
	defer res.Body.Close()

	// read the plain body html and get the csrfToken
	bodyBytes, _ := ioutil.ReadAll(res.Body)
	bodyLines := strings.Split(string(bodyBytes), "\n")

	// parse out the csrfToken
	// TODO: replace this with regex
	var csrfToken string
	for _, bodyLine := range bodyLines {
		if strings.Contains(bodyLine, "csrfToken") {
			stringNoSpaces := strings.ReplaceAll(bodyLine, " ", "")
			stringRemovedLeft := strings.ReplaceAll(stringNoSpaces, "varcsrfToken='", "")
			csrfToken = strings.ReplaceAll(stringRemovedLeft, "';", "")
			break
		}
	}

	// create the url vals to be posted, so that we can login
	values := make(url.Values)
	values.Set("username", username)
	values.Set("password", password)
	values.Set("csrf_token", csrfToken)

	// try to login into airflow with given creds
	// if we can't login w'll come back to the login page
	// if we can w'll see the dags table
	res, err = client.PostForm(airflowLoginURL, values)
	assert.NoError(t, err)
	assert.Equal(t, true, res.StatusCode >= 200 && res.StatusCode < 400)
	defer res.Body.Close()

	// check on which page we are login or dags
	doc, _ := goquery.NewDocumentFromReader(res.Body)
	loginBoxExists := doc.Find("div#loginbox").Length() == 1
	dagsTableExists := doc.Find("table#dags").Length() == 1

	assert.Equal(t, false, loginBoxExists)
	assert.Equal(t, true, dagsTableExists)
}

func getPreexistingTerraformOptions(t *testing.T, region string, resourcePrefix string, resourceSuffix string) (*terraform.Options, error) {
	tempTestFolder := testStructure.CopyTerraformFolderToTemp(t, "preexisting", ".")

	terraformOptions := &terraform.Options{
		TerraformDir:       tempTestFolder,
		Vars:               map[string]interface{}{},
		MaxRetries:         5,
		TimeBetweenRetries: 5 * time.Minute,
		NoColor:            true,
		Logger:             logger.TestingT,
	}

	terraformOptions.Vars["region"] = region
	terraformOptions.Vars["resource_prefix"] = resourcePrefix
	terraformOptions.Vars["resource_suffix"] = resourceSuffix
	terraformOptions.Vars["extra_tags"] = map[string]interface{}{
		"ATestTag":       "a_test_tag",
		"ResourcePrefix": resourcePrefix,
		"ResourceSuffix": resourceSuffix,
	}

	terraformOptions.Vars["vpc_id"] = "vpc-0eafa6867cb3bdaa3"
	terraformOptions.Vars["public_subnet_ids"] = []string{
		"subnet-08da686d46e99872d",
		"subnet-0e5bb83f963f8df0f",
	}
	terraformOptions.Vars["private_subnet_ids"] = []string{
		"subnet-03c2a3885cfc8a740",
		"subnet-09c0ce0aff676904a",
	}

	terraformOptions.Vars["rds_name"] = AddPreAndSuffix("preexisting", resourcePrefix, resourceSuffix)
	terraformOptions.Vars["route53_zone_name"] = "aws-sandbox.dataroots.io"

	return terraformOptions, nil
}

func getDefaultTerraformOptions(t *testing.T, region string, resourcePrefix string, resourceSuffix string) (*terraform.Options, error) {
	tempTestFolder := testStructure.CopyTerraformFolderToTemp(t, "..", ".")

	terraformOptions := &terraform.Options{
		TerraformDir:       tempTestFolder,
		Vars:               map[string]interface{}{},
		MaxRetries:         5,
		TimeBetweenRetries: 5 * time.Minute,
		NoColor:            true,
		Logger:             logger.TestingT,
	}

	terraformOptions.Vars["region"] = region
	terraformOptions.Vars["resource_prefix"] = resourcePrefix
	terraformOptions.Vars["resource_suffix"] = resourceSuffix
	terraformOptions.Vars["extra_tags"] = map[string]interface{}{
		"ATestTag":       "a_test_tag",
		"ResourcePrefix": resourcePrefix,
		"ResourceSuffix": resourceSuffix,
	}

	terraformOptions.Vars["airflow_image_name"] = "apache/airflow"
	terraformOptions.Vars["airflow_image_tag"] = "1.10.12"
	terraformOptions.Vars["airflow_log_region"] = region
	terraformOptions.Vars["airflow_log_retention"] = "7"
	terraformOptions.Vars["airflow_example_dag"] = true
	terraformOptions.Vars["airflow_variables"] = map[string]interface{}{
		"AIRFLOW__WEBSERVER__NAVBAR_COLOR": "#e27d60",
	}
	terraformOptions.Vars["airflow_executor"] = "Local"

	terraformOptions.Vars["ecs_cpu"] = 2048
	terraformOptions.Vars["ecs_memory"] = 4096

	terraformOptions.Vars["ip_allow_list"] = []string{
		"0.0.0.0/0",
	}
	terraformOptions.Vars["vpc_id"] = "vpc-0eafa6867cb3bdaa3"
	terraformOptions.Vars["public_subnet_ids"] = []string{
		"subnet-08da686d46e99872d",
		"subnet-0e5bb83f963f8df0f",
	}
	terraformOptions.Vars["private_subnet_ids"] = []string{
		"subnet-03c2a3885cfc8a740",
		"subnet-09c0ce0aff676904a",
	}

	// Get password and username from env vars
	terraformOptions.Vars["postgres_uri"] = ""
	terraformOptions.Vars["rds_username"] = "dataroots"
	terraformOptions.Vars["rds_password"] = "dataroots"
	terraformOptions.Vars["rds_instance_class"] = "db.t2.micro"
	terraformOptions.Vars["rds_availability_zone"] = fmt.Sprintf("%sa", region)
	terraformOptions.Vars["rds_skip_final_snapshot"] = true
	terraformOptions.Vars["rds_deletion_protection"] = false

	terraformOptions.Vars["use_https"] = true
	terraformOptions.Vars["route53_zone_name"] = "aws-sandbox.dataroots.io"

	return terraformOptions, nil
}

func TestApplyAndDestroyWithDefaultValues(t *testing.T) {
	fmt.Println("Starting test: TestApplyAndDestroyWithDefaultValues")
	// 'GLOBAL' test vars
	region := "eu-west-1"
	resourcePrefix := "dtr"
	resourceSuffix := strings.ToLower(random.UniqueId())

	// TODO: Check the task def rev number before and after apply and see if the rev num has increased by 1

	t.Parallel()

	options, err := getDefaultTerraformOptions(t, region, resourcePrefix, resourceSuffix)
	assert.NoError(t, err)

	// terraform destroy => when test completes
	defer terraform.Destroy(t, options)
	fmt.Println("Running: terraform init && terraform apply")
	_, err = terraform.InitE(t, options)
	assert.NoError(t, err)
	_, err = terraform.PlanE(t, options)
	assert.NoError(t, err)
	_, err = terraform.ApplyE(t, options)
	assert.NoError(t, err)

	// if there are terraform errors, do nothing
	if err == nil {
		fmt.Println("Terraform apply returned no error, continuing")
		validateCluster(t, options, region, resourcePrefix, resourceSuffix)
	}
}

func TestApplyAndDestroyWithPlainHTTP(t *testing.T) {
	fmt.Println("Starting test: TestApplyAndDestroyWithPlainHTTP")
	// 'GLOBAL' test vars
	region := "eu-west-1"
	resourcePrefix := "dtr"
	resourceSuffix := strings.ToLower(random.UniqueId())

	// TODO: Check the task def rev number before and after apply and see if the rev num has increased by 1

	t.Parallel()

	options, err := getDefaultTerraformOptions(t, region, resourcePrefix, resourceSuffix)
	assert.NoError(t, err)
	options.Vars["use_https"] = false
	options.Vars["route53_zone_name"] = ""

	// terraform destroy => when test completes
	defer terraform.Destroy(t, options)
	fmt.Println("Running: terraform init && terraform apply")
	_, err = terraform.InitE(t, options)
	assert.NoError(t, err)
	_, err = terraform.PlanE(t, options)
	assert.NoError(t, err)
	_, err = terraform.ApplyE(t, options)
	assert.NoError(t, err)

	// if there are terraform errors, do nothing
	if err == nil {
		fmt.Println("Terraform apply returned no error, continuing")
		validateCluster(t, options, region, resourcePrefix, resourceSuffix)
	}
}

func TestApplyAndDestroyWithPlainHTTPAndSequentialExecutor(t *testing.T) {
	fmt.Println("Starting test: TestApplyAndDestroyWithPlainHTTPAndSequentialExecutor")
	// 'GLOBAL' test vars
	region := "eu-west-1"
	resourcePrefix := "dtr"
	resourceSuffix := strings.ToLower(random.UniqueId())

	// TODO: Check the task def rev number before and after apply and see if the rev num has increased by 1

	t.Parallel()

	options, err := getDefaultTerraformOptions(t, region, resourcePrefix, resourceSuffix)
	assert.NoError(t, err)
	options.Vars["airflow_executor"] = "Sequential"

	options.Vars["use_https"] = false
	options.Vars["route53_zone_name"] = ""

	// terraform destroy => when test completes
	defer terraform.Destroy(t, options)
	fmt.Println("Running: terraform init && terraform apply")
	_, err = terraform.InitE(t, options)
	assert.NoError(t, err)
	_, err = terraform.PlanE(t, options)
	assert.NoError(t, err)
	_, err = terraform.ApplyE(t, options)
	assert.NoError(t, err)

	// if there are terraform errors, do nothing
	if err == nil {
		fmt.Println("Terraform apply returned no error, continuing")
		validateCluster(t, options, region, resourcePrefix, resourceSuffix)
	}
}

func TestApplyAndDestroyWithPlainHTTPAndSequentialExecutorOnlyPublicSubnet(t *testing.T) {
	fmt.Println("Starting test: TestApplyAndDestroyWithPlainHTTPAndSequentialExecutorOnlyPublicSubnet")
	// 'GLOBAL' test vars
	region := "eu-west-1"
	resourcePrefix := "dtr"
	resourceSuffix := strings.ToLower(random.UniqueId())

	// TODO: Check the task def rev number before and after apply and see if the rev num has increased by 1

	t.Parallel()

	options, err := getDefaultTerraformOptions(t, region, resourcePrefix, resourceSuffix)
	assert.NoError(t, err)
	options.Vars["airflow_executor"] = "Sequential"

	options.Vars["private_subnet_ids"] = []string{}

	options.Vars["use_https"] = false
	options.Vars["route53_zone_name"] = ""

	// terraform destroy => when test completes
	defer terraform.Destroy(t, options)
	fmt.Println("Running: terraform init && terraform apply")
	_, err = terraform.InitE(t, options)
	assert.NoError(t, err)
	_, err = terraform.PlanE(t, options)
	assert.NoError(t, err)
	_, err = terraform.ApplyE(t, options)
	assert.NoError(t, err)

	// if there are terraform errors, do nothing
	if err == nil {
		fmt.Println("Terraform apply returned no error, continuing")
		validateCluster(t, options, region, resourcePrefix, resourceSuffix)
	}
}

func TestApplyAndDestroyWithPlainHTTPAndSequentialExecutorUsingRBAC(t *testing.T) {
	fmt.Println("Starting test: TestApplyAndDestroyWithPlainHTTPAndSequentialExecutorUsingRBAC")
	// 'GLOBAL' test vars
	region := "eu-west-1"
	resourcePrefix := "dtr"
	resourceSuffix := strings.ToLower(random.UniqueId())

	// TODO: Check the task def rev number before and after apply and see if the rev num has increased by 1

	t.Parallel()

	options, err := getDefaultTerraformOptions(t, region, resourcePrefix, resourceSuffix)
	assert.NoError(t, err)
	options.Vars["airflow_executor"] = "Sequential"
	options.Vars["airflow_authentication"] = "rbac"

	options.Vars["use_https"] = false
	options.Vars["route53_zone_name"] = ""

	// terraform destroy => when test completes
	defer terraform.Destroy(t, options)
	fmt.Println("Running: terraform init && terraform apply")
	_, err = terraform.InitE(t, options)
	assert.NoError(t, err)
	_, err = terraform.PlanE(t, options)
	assert.NoError(t, err)
	_, err = terraform.ApplyE(t, options)
	assert.NoError(t, err)

	// if there are terraform errors, do nothing
	if err == nil {
		fmt.Println("Terraform apply returned no error, continuing")
		validateCluster(t, options, region, resourcePrefix, resourceSuffix)
	}
}

func TestApplyAndDestroyWithPlainHTTPAndPreexistingRDS(t *testing.T) {
	fmt.Println("Starting test: TestApplyAndDestroyWithPlainHTTPAndPreexistingRDS")
	// 'GLOBAL' test vars
	region := "eu-west-1"
	resourcePrefix := "dtr"
	resourceSuffix := strings.ToLower(random.UniqueId())

	// TODO: Check the task def rev number before and after apply and see if the rev num has increased by 1

	t.Parallel()

	preExistingOptions, err := getPreexistingTerraformOptions(t, region, resourcePrefix, resourceSuffix)
	assert.NoError(t, err)

	// terraform destroy => when test completes
	defer terraform.Destroy(t, preExistingOptions)
	fmt.Println("Running: terraform init && terraform apply")
	_, err = terraform.InitE(t, preExistingOptions)
	assert.NoError(t, err)
	_, err = terraform.PlanE(t, preExistingOptions)
	assert.NoError(t, err)
	_, err = terraform.ApplyE(t, preExistingOptions)
	assert.NoError(t, err)

	options, err := getDefaultTerraformOptions(t, region, resourcePrefix, resourceSuffix)
	assert.NoError(t, err)
	options.Vars["postgres_uri"] = terraform.Output(t, preExistingOptions, "postgres_uri")
	options.Vars["certificate_arn"] = terraform.Output(t, preExistingOptions, "certificate_arn")

	// terraform destroy => when test completes
	defer terraform.Destroy(t, options)
	fmt.Println("Running: terraform init && terraform apply")
	_, err = terraform.InitE(t, options)
	assert.NoError(t, err)
	_, err = terraform.PlanE(t, options)
	assert.NoError(t, err)
	_, err = terraform.ApplyE(t, options)
	assert.NoError(t, err)
	// if there are terraform errors, do nothing
	if err == nil {
		fmt.Println("Terraform apply returned no error, continuing")
		validateCluster(t, options, region, resourcePrefix, resourceSuffix)
	}
}
