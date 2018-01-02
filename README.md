# Terraform Wrapper Script
 - Originally adapted from https://github.com/bkc1/terraform-multi-env

## Terraform wrapper script for managing multiple deployments and environments in AWS to support Pivotal Cloud Foundry.

### This is specific to a particular environment, but usable with some minor modifications.

#### Considerations:
 - 3 separate AWS environments - sandbox, nonprod, prod
 - Used terraform version 0.9.11
 - AWS S3 for state storage
 - Uses current directory to determine which set of scripts are utilized
 - Uses AWS CLI profiles for auth (based on macOS)
  - In this case, one profile for each env: `sb`,`np`,`pr` (sandbox, nonprod, prod)
 - Uses sym-linked script in each of the deployment directories

#### Assumes terraform scripts in the following locations:
```
|-- terraform
     |-- tf.sh
     |-- aws-service-broker
     |-- bootstrap
     |-- kong
     |-- pcf-base
         |-- sandbox
         |-- nonprod
         |-- prod
     |-- modules
     |-- rabbit
```

##### Examples:
- `plan-command` outputs the commands that will be used based on the supplied operators. This command takes no action.

```
$ ./tf.sh sb plan-command

COMMANDS ONLY - NO ACTION TAKEN

The command for terraform plan for  <customer-name>  environment in AWS us-east-1:

terraform init -backend-config=bucket=sandbox-pcf-terraform -backend-config=profile=sb

terraform plan -var-file=/Users/thad/keys/ecs/sandbox-pcf-secrets.tfvars -var-file=../ipwhitelist.tfvars
```

 - `plan` runs the `terraform plan` command against the `sandbox` environment (`sb`).

```
$ ./tf.sh sb plan
```

- `apply` runs the `terraform apply` command against the `prod` environment (`pr`). It will confirm the details of your current operators and will ask you if you want to apply.

```
$ ./tf.sh pr apply
```
