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
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TerraformInitPlanApply(t *testing.T, terraformOptions *terraform.Options) {
	t.Parallel()
	defer terraform.Destroy(t, terraformOptions)

	fmt.Println("Running: terraform init")
	_, errInit := terraform.InitE(t, terraformOptions)
	assert.NoError(t, errInit)
	fmt.Println("Running: terraform plan")
	_, errPlan := terraform.PlanE(t, terraformOptions)
	assert.NoError(t, errPlan)
	fmt.Println("Running: terraform apply")
	_, errApply := terraform.ApplyE(t, terraformOptions)
	assert.NoError(t, errApply)
}

func CheckIfRolesExist(t *testing.T, region string, rolesToCheck []string) {
	fmt.Println("Checking if roles exists")
	iamClient := aws.NewIamClient(t, region)

	for _, roleName := range rolesToCheck {
		roleInput := &iam.GetRoleInput{RoleName: &roleName}
		_, err := iamClient.GetRole(roleInput)
		assert.NoError(t, err)
	}
}

func CheckClusterAndContainerStates(t *testing.T, region string, resourcePrefix string, resourceSuffix string) {
	retrySleepTime := time.Duration(10) * time.Second
	ecsGetTaskArnMaxRetries := 20
	ecsGetTaskStatusMaxRetries := 50
	desiredStatusRunning := "RUNNING"

	clusterName := AddPreAndSuffix("airflow", resourcePrefix, resourceSuffix)
	serviceName := AddPreAndSuffix("airflow", resourcePrefix, resourceSuffix)
	webserverContainerName := AddPreAndSuffix("airflow-webserver", resourcePrefix, resourceSuffix)
	schedulerContainerName := AddPreAndSuffix("airflow-scheduler", resourcePrefix, resourceSuffix)
	sidecarContainerName := AddPreAndSuffix("airflow-sidecar", resourcePrefix, resourceSuffix)
	initContainerName := AddPreAndSuffix("airflow-init", resourcePrefix, resourceSuffix)

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
	fmt.Println("Checking that there is only one task running")
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
		var initContainer ecs.Container
		for i := 0; i < ecsGetTaskStatusMaxRetries; i++ {
			fmt.Printf("Getting container statuses, try... %d\n", i)

			describeTasks, _ := ecsClient.DescribeTasks(describeTasksInput)
			airflowTask := describeTasks.Tasks[0]
			containers := airflowTask.Containers

			webserverContainer = *GetContainerWithName(webserverContainerName, containers)
			schedulerContainer = *GetContainerWithName(schedulerContainerName, containers)
			sidecarContainer = *GetContainerWithName(sidecarContainerName, containers)
			initContainer = *GetContainerWithName(initContainerName, containers)

			if *webserverContainer.LastStatus == "RUNNING" &&
				*schedulerContainer.LastStatus == "RUNNING" &&
				*sidecarContainer.LastStatus == "STOPPED" &&
				*initContainer.LastStatus == "STOPPED" {
				break
			}
			time.Sleep(retrySleepTime)
		}
		assert.Equal(t, "RUNNING", *webserverContainer.LastStatus)
		assert.Equal(t, "RUNNING", *schedulerContainer.LastStatus)
		assert.Equal(t, "STOPPED", *sidecarContainer.LastStatus)
		assert.Equal(t, "STOPPED", *initContainer.LastStatus)
	}
}

func CheckIfWebserverIsHealthy(t *testing.T, airflowURL string) {
	// We do consecutive checks because sometime it could be that
	// the webserver is available for a short amount of time and crashes
	// a couple of seconds later
	fmt.Println("Doing HTTP request/checking health")
	retrySleepTime := time.Duration(10) * time.Second
	httpStatusCodeMaxRetries := 15
	amountOfConsecutiveGetsToBeHealthy := 3

	var amountOfConsecutiveHealthyChecks int
	var res *http.Response
	for i := 0; i < httpStatusCodeMaxRetries; i++ {
		fmt.Printf("Doing HTTP request to airflow webservice, try... %d\n", i)
		res, errGet := http.Get(airflowURL)
		if res != nil && errGet == nil {
			fmt.Println(res.StatusCode)
			if res.StatusCode >= 200 && res.StatusCode < 400 {
				fmt.Println("Webservice is healthy")
				amountOfConsecutiveHealthyChecks++
			} else {
				fmt.Println("Webservice is NOT healthy")
				amountOfConsecutiveHealthyChecks = 0
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
	}
}

func CheckAirflowNavbarColor(t *testing.T, airflowURL string, expectedNavbarColor string) {
	res, errGet := http.Get(airflowURL)
	assert.NoError(t, errGet)

	if res != nil && res.StatusCode >= 200 && res.StatusCode < 400 {
		fmt.Println("Getting the actual HTML code")
		defer res.Body.Close()
		doc, err := goquery.NewDocumentFromReader(res.Body)
		assert.NoError(t, err)

		fmt.Println("Checking if the navbar has the correct color")
		navbarStyle, exists := doc.Find(".navbar.navbar-inverse.navbar-fixed-top").First().Attr("style")
		assert.Equal(t, true, exists)
		assert.Contains(t, navbarStyle, fmt.Sprintf("background-color: %s", expectedNavbarColor))
	}
}

func CheckIfLoginToAirflowIsPossible(t *testing.T, airflowURL string) {
	username := "admin"
	password := "admin"
	airflowLoginURL := fmt.Sprintf("%s/login/", airflowURL)

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
