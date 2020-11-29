package test

import (
	"fmt"

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

	airflowVariables := terraformOptions.Vars["airflow_variables"].(map[string]interface{})
	if _, ok := airflowVariables["AIRFLOW__WEBSERVER__NAVBAR_COLOR"]; ok {
		navbarColor = airflowVariables["AIRFLOW__WEBSERVER__NAVBAR_COLOR"].(string)
	}
	return navbarColor
}
