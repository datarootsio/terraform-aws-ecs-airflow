# Terraform module Airflow on AWS ECS

This is a module for Terraform that deploys Airflow in AWS.

[![maintained by dataroots](https://img.shields.io/badge/maintained%20by-dataroots-%2300b189)](https://dataroots.io)
[![Terraform 0.13](https://img.shields.io/badge/terraform-0.13-%23623CE4)](https://www.terraform.io)
[![Terraform Registry](https://img.shields.io/badge/terraform-registry-%23623CE4)](https://registry.terraform.io/modules/datarootsio/aws-airflow/module/)
[![tests](https://github.com/datarootsio/terraform-aws-ecs-airflow/workflows/tests/badge.svg?branch=master)](https://github.com/datarootsio/terraform-aws-ecs-airflow/actions)
[![Go Report Card](https://goreportcard.com/badge/github.com/datarootsio/terraform-aws-ecs-airflow)](https://goreportcard.com/report/github.com/datarootsio/terraform-aws-ecs-airflow)

## Intend

The airflow setup provided with this module is 

## Usage

```hcl
module "airflow" {
    source = "../terraform-aws-ecs-airflow"

    resource_prefix = "my-awesome-company"
    resource_suffix = "env"

    vpc_id             = "vpc-123456"
    public_subnet_ids  = ["subnet-456789", "subnet-098765"]

    use_https = false

    rds_username            = "dataroots"
    rds_password            = "dataroots"
    rds_availability_zone   = "eu-west-1a"
    rds_deletion_protection = false
}
```

## Todo

- [ ] Option to use SQL instead of Postgres
- [ ] RBAC
- [ ] Support for [Google OAUTH ](https://airflow.readthedocs.io/en/latest/security.html#google-authentication)

<!--- BEGIN_TF_DOCS --->
<!--- END_TF_DOCS --->

## Contributing

Contributions to this repository are very welcome! Found a bug or do you have a suggestion? Please open an issue. Do you know how to fix it? Pull requests are welcome as well! To get you started faster, a Makefile is provided.

Make sure to install [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html), [Go](https://golang.org/doc/install) (for automated testing) and Make (optional, if you want to use the Makefile) on your computer. Install [tflint](https://github.com/terraform-linters/tflint) to be able to run the linting.

* Setup tools & dependencies: `make tools`
* Format your code: `make fmt`
* Linting: `make lint`
* Run tests: `make test` (or `go test -timeout 2h ./...` without Make)

## License

MIT license. Please see [LICENSE](LICENSE.md) for details.