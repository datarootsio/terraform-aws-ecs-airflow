[![Maintained by dataroots](https://img.shields.io/badge/maintained%20by-dataroots-%2300b189)](https://dataroots.io)
[![Airflow version](https://img.shields.io/badge/Apache%20Airflow-2.0.1-e27d60.svg)](https://airflow.apache.org/)
[![Terraform 0.15](https://img.shields.io/badge/terraform-0.15-%23623CE4)](https://www.terraform.io)
[![Terraform Registry](https://img.shields.io/badge/terraform-registry-%23623CE4)](https://registry.terraform.io/modules/datarootsio/ecs-airflow/aws)
[![Tests](https://github.com/datarootsio/terraform-aws-ecs-airflow/workflows/tests/badge.svg?branch=main)](https://github.com/datarootsio/terraform-aws-ecs-airflow/actions)
[![Go Report Card](https://goreportcard.com/badge/github.com/datarootsio/terraform-aws-ecs-airflow)](https://goreportcard.com/report/github.com/datarootsio/terraform-aws-ecs-airflow)

![](https://scontent.fbru1-1.fna.fbcdn.net/v/t1.0-9/94305647_112517570431823_3318660558911176704_o.png?_nc_cat=111&_nc_sid=e3f864&_nc_ohc=-spbrtnzSpQAX_qi7iI&_nc_ht=scontent.fbru1-1.fna&oh=483d147a29972c72dfb588b91d57ac3c&oe=5F99368A "Logo")

# Terraform module Airflow on AWS ECS

This is a module for Terraform that deploys Airflow in AWS.

## Setup

- An ECS Service with:
    - Sidecar injection container
    - Airflow init container
    - Airflow webserver container
    - Airflow scheduler container
- An ALB
- A RDS instance (optional but recommended)
- A DNS Record (optional but recommended)
- A S3 Bucket (optional)

Average cost of the minimal setup (with RDS): ~50$/Month

Why do I need a RDS instance? 
1. This makes Airflow statefull, you will be able to rerun failed dags, keep history of failed/succeeded dags, ...
2. It allows for dags to run concurrently, otherwise two dags will not be able to run at the same time
3. The state of your dags persists, even if the Airflow container fails or if you update the container definition (this will trigger an update of the ECS task)

## Intend

The Airflow setup provided with this module, is a setup where the only task of Airflow is to manage your jobs/workflows. So not to do actually heavy lifting like SQL queries, Spark jobs, ... . Offload as many task to AWS Lambda, AWS EMR, AWS Glue, ... . If you want Airflow to have access to these services, use the output role and give it permissions to these services through IAM.

## Usage

```hcl
module "airflow" {
    source = "datarootsio/ecs-airflow/aws"

    resource_prefix = "my-awesome-company"
    resource_suffix = "env"

    vpc_id             = "vpc-123456"
    public_subnet_ids  = ["subnet-456789", "subnet-098765"]

    rds_password = "super-secret-pass"
}
```
(This will create Airflow, backed up by an RDS (both in a public subnet) and without https)

[Press here to see more examples](https://github.com/datarootsio/terraform-aws-ecs-airflow/tree/main/examples)

Note: After that Terraform is done deploying everything, it can take up to a minute for Airflow to be available through HTTP(S)

## Adding DAGs

To add dags, upload them to the created S3 bucket in the subdir "dags/". After you uploaded them run the seed dag. This will sync the s3 bucket with the local dags folder of the ECS container.

## Authentication

For now the only authentication option is 'RBAC'. When enabling this, this module will create a default admin role (only if there are no users in the database). This default role is just a one time entrypoint in to the airflow web interface. When you log in for the first time immediately change the password! Also with this default admin role you can create any user you want.

## Todo

- [ ] RDS Backup options
- [ ] Option to use SQL instead of Postgres
- [ ] Add a Lambda function that triggers the sync dag (so that you can auto sync through ci/cd)
- [x] RBAC
- [ ] Support for [Google OAUTH](https://airflow.readthedocs.io/en/latest/security.html#google-authentication)

<!--- BEGIN_TF_DOCS --->
Error: Argument or block definition required: An argument or block definition is required here.

<!--- END_TF_DOCS --->

## Makefile Targets

```text
Available targets:

  tools                             Pull Go and Terraform dependencies
  fmt                               Format Go and Terraform code
  lint/lint-tf/lint-go              Lint Go and Terraform code
  test/testverbose                  Run tests

```

## Contributing

Contributions to this repository are very welcome! Found a bug or do you have a suggestion? Please open an issue. Do you know how to fix it? Pull requests are welcome as well! To get you started faster, a Makefile is provided.

Make sure to install [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html), [Go](https://golang.org/doc/install) (for automated testing) and Make (optional, if you want to use the Makefile) on your computer. Install [tflint](https://github.com/terraform-linters/tflint) to be able to run the linting.

* Setup tools & dependencies: `make tools`
* Format your code: `make fmt`
* Linting: `make lint`
* Run tests: `make test` (or `go test -timeout 2h ./...` without Make)

Make sure you branch from the 'open-pr-here' branch, and submit a PR back to the 'open-pr-here' branch.

## License

MIT license. Please see [LICENSE](LICENSE.md) for details.
