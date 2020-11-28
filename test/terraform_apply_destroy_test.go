package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	testStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

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
		ValidateCluster(t, options, region, resourcePrefix, resourceSuffix)
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
		ValidateCluster(t, options, region, resourcePrefix, resourceSuffix)
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
		ValidateCluster(t, options, region, resourcePrefix, resourceSuffix)
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
		ValidateCluster(t, options, region, resourcePrefix, resourceSuffix)
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
		ValidateCluster(t, options, region, resourcePrefix, resourceSuffix)
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
		ValidateCluster(t, options, region, resourcePrefix, resourceSuffix)
	}
}
