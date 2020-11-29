package test

import (
	"fmt"
	"testing"

	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// AddPreAndSuffix adds a pre and suffix to a string
func AddPreAndSuffix(resourceName string, resourcePrefix string, resourceSuffix string) string {
	if resourcePrefix == "" {
		resourcePrefix = "dataroots"
	}
	if resourceSuffix == "" {
		resourceSuffix = "dev"
	}
	return fmt.Sprintf("%s-%s-%s", resourcePrefix, resourceName, resourceSuffix)
}

// GetContainerWithName will return a container given a container name
func GetContainerWithName(containerName string, containers []*ecs.Container) *ecs.Container {
	for _, container := range containers {
		if *container.Name == containerName {
			return container
		}
	}
	return nil
}

// GetAirflowNavbarColor will get the navbar color from either the airflow_variables or the default value
func GetAirflowNavbarColor(terraformOptions *terraform.Options) string {
	// default navbar color
	navbarColor := "#007A87"

	if _, ok := terraformOptions.Vars["airflow_variables"]; ok {
		airflowVariables := terraformOptions.Vars["airflow_variables"].(map[string]interface{})
		if _, ok := airflowVariables["AIRFLOW__WEBSERVER__NAVBAR_COLOR"]; ok {
			navbarColor = airflowVariables["AIRFLOW__WEBSERVER__NAVBAR_COLOR"].(string)
		}
	}
	return navbarColor
}

// GetRBACUsername will get the rbac username from either the terraformOptions or the default value
func GetRBACUsername(terraformOptions *terraform.Options) string {
	// default rbac username
	rbacUsername := "admin"

	if _, ok := terraformOptions.Vars["rbac_admin_username"]; ok {
		rbacUsername = terraformOptions.Vars["rbac_admin_username"].(string)
	}
	return rbacUsername
}

// GetRBACPassword will get the rbac password from either the terraformOptions or the default value
func GetRBACPassword(terraformOptions *terraform.Options) string {
	// default rbac password
	rbacPassword := "admin"

	if _, ok := terraformOptions.Vars["rbac_admin_password"]; ok {
		rbacPassword = terraformOptions.Vars["rbac_admin_password"].(string)
	}
	return rbacPassword
}

// GetAirflowURL creates the correct airflow url
func GetAirflowURL(t *testing.T, terraformOptions *terraform.Options) string {
	protocol := "http"
	airflowAlbDNS := terraform.Output(t, terraformOptions, "airflow_dns_record")

	if terraformOptions.Vars["use_https"].(bool) == true {
		protocol = "https"
	}
	if terraformOptions.Vars["route53_zone_name"].(string) == "" {
		airflowAlbDNS = terraform.Output(t, terraformOptions, "airflow_alb_dns")
	}

	airflowURL := fmt.Sprintf("%s://%s", protocol, airflowAlbDNS)
	return airflowURL
}
