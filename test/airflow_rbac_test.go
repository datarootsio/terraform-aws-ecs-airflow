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
)

func getTerraformOptionsAirflowRBAC(t *testing.T, region string, resourcePrefix string, resourceSuffix string) *terraform.Options {
	tempTestFolder := testStructure.CopyTerraformFolderToTemp(t, "..", ".")

	terraformOptions := &terraform.Options{
		TerraformDir:       tempTestFolder,
		Vars:               map[string]interface{}{},
		MaxRetries:         5,
		TimeBetweenRetries: 5 * time.Minute,
		NoColor:            true,
		Logger:             logger.TestingT,
	}

	// general options
	terraformOptions.Vars["region"] = region
	terraformOptions.Vars["resource_prefix"] = resourcePrefix
	terraformOptions.Vars["resource_suffix"] = resourceSuffix
	terraformOptions.Vars["extra_tags"] = map[string]interface{}{
		"ATestTag":       "a_test_tag",
		"ResourcePrefix": resourcePrefix,
		"ResourceSuffix": resourceSuffix,
	}

	// airflow options
	terraformOptions.Vars["airflow_log_region"] = region
	terraformOptions.Vars["airflow_log_retention"] = "7"
	terraformOptions.Vars["airflow_example_dag"] = true
	terraformOptions.Vars["airflow_variables"] = map[string]interface{}{
		"AIRFLOW__WEBSERVER__NAVBAR_COLOR": "#e27d60",
	}
	terraformOptions.Vars["airflow_executor"] = "Sequential"
	terraformOptions.Vars["airflow_authentication"] = "rbac"

	// rbac admin options
	terraformOptions.Vars["rbac_admin_username"] = "dataroots"
	terraformOptions.Vars["rbac_admin_password"] = "s3cRet_P4S5w0Rd"
	terraformOptions.Vars["rbac_admin_email"] = "airflow@admin.io"
	terraformOptions.Vars["rbac_admin_firstname"] = "Data"
	terraformOptions.Vars["rbac_admin_lastname"] = "Roots"

	// network options
	terraformOptions.Vars["vpc_id"] = "vpc-0eafa6867cb3bdaa3"
	terraformOptions.Vars["public_subnet_ids"] = []string{
		"subnet-08da686d46e99872d",
		"subnet-0e5bb83f963f8df0f",
	}
	terraformOptions.Vars["private_subnet_ids"] = []string{
		"subnet-03c2a3885cfc8a740",
		"subnet-09c0ce0aff676904a",
	}

	return terraformOptions
}

func TestAirflowRBAC(t *testing.T) {
	region := "eu-west-1"
	resourcePrefix := "dtr"
	resourceSuffix := strings.ToLower(random.UniqueId())

	t.Parallel()
	terraformOptions := getTerraformOptionsAirflowRBAC(t, region, resourcePrefix, resourceSuffix)

	// terraform destroy => when test completes
	defer terraform.Destroy(t, terraformOptions)
	TerraformInitPlanApply(t, terraformOptions)

	rolesToCheck := []string{
		AddPreAndSuffix("airflow-task-execution-role", resourcePrefix, resourceSuffix),
		AddPreAndSuffix("airflow-task-role", resourcePrefix, resourceSuffix),
	}
	CheckIfRolesExist(t, region, rolesToCheck)

	CheckClusterAndContainerStates(t, region, resourcePrefix, resourceSuffix)

	webProtocol := "http"
	airflowAlbDNS := terraform.Output(t, terraformOptions, "airflow_alb_dns")
	airflowURL := fmt.Sprintf("%s://%s", webProtocol, airflowAlbDNS)
	CheckIfWebserverIsHealthy(t, airflowURL)

	airflowNavbarColor := GetAirflowNavbarColor(terraformOptions)
	CheckAirflowNavbarColor(t, airflowURL, airflowNavbarColor)

	username := GetRBACUsername(terraformOptions)
	password := GetRBACPassword(terraformOptions)
	CheckIfLoginToAirflowIsPossible(t, airflowURL, username, password)
}
