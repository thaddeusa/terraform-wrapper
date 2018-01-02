#!/bin/bash
set -e

# terraform wrapper script for managing multiple environments

# Currently works with Terraform Version 0.9.11
# In the case below (verion 9), you must have the binary in your path and it must be named 'tf9'
# tfver=<terraform binary>
tfver=tf9

display_usage() {
	echo -e "\033[31mThe environment and a supported terraform command must be defined."
	echo -e "\033[31mThe terraform module/sub-environment is defined by the current directory."
	echo -e "\nUsage:\n$0 [sb,np,pr] [plan|apply|destroy|taint|untaint|show|plan-destroy|plan-command] \n\033[0m"
	echo -e "\nTo see the commands that will be run with your chosen variables, use 'plan-command'."
	echo -e "Example: ./tf.sh sb plan-command\n"
	exit 1
	}

dir_match() {
	echo -e "\n\033[32mDirectory matches environment... proceeding.\033[0m"
	sleep 1s
}

dir_fail_match() {
	echo -e "\n\033[31mDirectory does not match a supported environment... aborting.\033[0m\n"
	#display_usage
	exit 1
}

if [[ $1 == "--help" || $1 == "-h" || $# -ne 2 ]]; then
	display_usage
	exit 1
fi

#Make sure terraform is installed
type $tfver >/dev/null 2>&1 || { echo >&2 "Terraform is not installed or in your path, exiting."; exit 1; }

#set variables based on environment setting
if [ $1 == "sb" ]; then
	ACCOUNT=sandbox
elif [ $1 = "np" ]; then
	ACCOUNT=nonprod
elif [ $1 = "pr" ]; then
	ACCOUNT=prod
else
	echo -e "\033[31mERROR: Account must be set to [sb|np|pr] \033[0m"
        display_usage
        exit 1
fi

PCFBASE=`dirname $(basename $(dirname $(pwd)))/$(basename $(pwd))`
if [ $PCFBASE = pcf-base ]; then
	TFMOD=pcf
elif [ `basename $PWD` = aws-service-broker ]; then
	TFMOD=awssb
else
	TFMOD=`basename $PWD`
fi

REGION=us-east-1
ENVIRONMENT=ecs
TFVAR=$ACCOUNT.tfvars
S3_BUCKET=$ACCOUNT-pcf-terraform
PROFILE=$1
SECRETS_PCF=~/keys/ecs/$ACCOUNT-pcf-secrets.tfvars
SECRETS_AWSSB=~/keys/ecs/$ACCOUNT-$TFMOD-secrets.tfvars
IPWHITELIST=../ipwhitelist.tfvars
#TFSCRIPT=$2

if [ $TFMOD == "pcf" ]; then
	STATE_FILE=terraform.tfstate
	VARFILES="-var-file=$SECRETS_PCF -var-file=$IPWHITELIST"
elif [ $TFMOD == "awssb" ]; then
	STATE_FILE=aws-service-broker-terraform.tfstate
	VARFILES="-var-file=$TFVAR -var-file=$SECRETS_AWSSB"
elif [ $TFMOD == "bootstrap" ]; then
	STATE_FILE=bootstrap-terraform.tfstate
	S3_BUCKET=$ACCOUNT-pcf-ecs-bootstrap
	VARFILES="-var-file=$TFVAR"
elif [ $TFMOD == "rabbit" ]; then
	STATE_FILE=rabbitmq-terraform.tfstate
	VARFILES="-var-file=$TFVAR"
else
	dir_fail_match
  display_usage
  exit 1
fi

tfinit="$tfver init -backend-config=bucket=${S3_BUCKET} -backend-config=profile=${PROFILE}"

plan() {
	echo -e "Running terraform plan for \033[32m ${ENVIRONMENT}-${ACCOUNT} \033[0m environment in AWS ${REGION}"
	sleep 2
	$tfver plan $VARFILES
}

plan-command() {
	echo -e "\nHere's the command for terraform plan for \033[32m ${ENVIRONMENT}-${ACCOUNT} \033[0m environment in AWS ${REGION}:"
	echo -e "\n\033[32m$tfinit\033[0m"
	echo -e "\n\033[32m$tfver plan $VARFILES\033[0m"
	exit 1
}

plan-destroy() {
	echo -e "Running terraform destroy for \033[32m ${ENVIRONMENT}-${ACCOUNT} \033[0m environment in AWS ${REGION}.."
	$tfver plan -destroy $VARFILES
}

apply() {
	start="$(date +%s)"
	echo -e "Running terraform apply for \033[32m ${ENVIRONMENT}-${ACCOUNT} \033[0m environment in AWS ${REGION}.."
	sleep 1
	$tfver apply $VARFILES
	end="$(date +%s)"
	echo "================================================================="
        echo -e "\033[32mTerraform ran for $(($end - $start)) seconds \033[0m"
}

show() {
	echo -e "Running terraform show for \033[32m ${ENVIRONMENT}-${ACCOUNT} \033[0m environment in AWS ${REGION}.."
	sleep 2
	$tfver show
}


destroy() {
	echo -e "Running terraform destroy for \033[32m ${ENVIRONMENT}-${ACCOUNT} \033[0m environment in AWS ${REGION}.."
	$tfver destroy $VARFILES
}

if [[ $TFMOD == awssb || $TFMOD == rabbit || $TFMOD == bootstrap ]]; then
	dir_match
elif [ $TFMOD = pcf ]; then
	if [ $ACCOUNT = `basename $PWD` ]; then
			dir_match
		else
			dir_fail_match
	fi
else
	dir_fail_match
fi

#Check current env and region in local state, if it exists
if [ $2 = "plan-command" ]; then
	echo -e "\n\033[32mCOMMANDS ONLY - NO ACTION TAKEN\033[0m\n"
else
	LOCAL_STATE=.terraform/terraform.tfstate
	if [ -e $LOCAL_STATE ]; then
	CURRENT_ENV=`grep profile ${LOCAL_STATE} |head -1 | cut -d '"' -f 4`
	CURRENT_REGION=`grep region ${LOCAL_STATE} |head -1 | cut -d '"' -f 4`

		echo "Local $LOCAL_STATE file exists.."
		if [ "${CURRENT_ENV}" = $1 ] && [ "${CURRENT_REGION}" = ${REGION} ]; then
			echo -e "Local $LOCAL_STATE file is set to the \033[32m ${CURRENT_ENV} \033[0m environment and \033[32m ${CURRENT_REGION} \033[0m, proceeding.."
		else
			echo -e "Local $LOCAL_STATE file is not set to the environment or region specified, purging & initializing remote state..."
			rm -f ${LOCAL_STATE}
			$tfinit
		fi
	fi
 fi

if [ $2 = "plan" ]; then
	plan
elif [ $2 = "plan-command" ]; then
	plan-command
elif [ $2 = "apply" ]; then
	echo -e "You're about to \033[31m APPLY \033[0m in \033[32m $ENVIRONMENT-${ACCOUNT}\033[0m."
	read -p "Are you sure? y/n" -n 1 -r
	echo
		if [[ $REPLY =~ ^[Yy]$ ]]; then
    	apply
		fi
elif [ $2 = "taint" ]; then
  taint
elif [ $2 = "untaint" ]; then
  untaint
elif [ $2 = "show" ]; then
  show
elif [ $2 = "destroy" ]; then
 	destroy
elif [ $2 = "plan-destroy" ]; then
 	plan-destroy
else
	echo -e "\033[31m ERROR: [plan|apply|destroy|taint|untaint|show|plan-destroy] are the only subcommands supported \033[0m]"
        display_usage
        exit 1
fi
