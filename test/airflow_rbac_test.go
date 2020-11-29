package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	testStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func getTerraformOptionsAirflowRBAC(t *testing.T) *terraform.Options {
	tempTestFolder := testStructure.CopyTerraformFolderToTemp(t, "..", ".")

	terraformOptions := &terraform.Options{
		TerraformDir:       tempTestFolder,
		Vars:               map[string]interface{}{},
		MaxRetries:         5,
		TimeBetweenRetries: 5 * time.Minute,
		NoColor:            true,
		Logger:             logger.TestingT,
	}

	return terraformOptions
}

func TestAirflowRBAC(t *testing.T) {
	t.Parallel()
	terraformOptions := getTerraformOptionsAirflowRBAC(t)

	region := terraformOptions.Vars["region"].(string)
	resourcePrefix := terraformOptions.Vars["resource_prefix"].(string)
	resourceSuffix := terraformOptions.Vars["resource_suffix"].(string)

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

	CheckIfLoginToAirflowIsPossible(t, airflowURL)
}
