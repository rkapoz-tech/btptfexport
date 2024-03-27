#!/bin/bash
# This script is used to generate the import statements for the resources on BTP into terraform code and terraform state.
# It`s necessary to btp-cli installed and configured to use this script.
# Author: Danilo Bovo <bovodanilo@gmail.com>
# Version: 1.2
#set -x
VERSION="Version: 1.0"

# Check if the btp-cli is installed
if ! command -v btp &> /dev/null; then
    echo "btp-cli could not be found. Please install it and configure it to use this script."
    exit 1
fi

# Check if the btp-cli is configured
if [ -z "$(btp --format json list accounts/subaccounts)" ]; then
    echo "btp-cli is not configured. Please configure it to use this script."
    exit 1
fi

BASEDIR=$(dirname $0)
. $BASEDIR/utils.sh

_generate_tf_code_for_environment() {
    sa_name=$(btp --format json get accounts/subaccounts $1 | jq -r '.displayName')
    # Generate the terraform code for the subaccount with the given GUID
    echo "# ------------------------------------------------------------------------------------------------------"
    echo "# Creation of subaccount environment instance"
    echo "# ------------------------------------------------------------------------------------------------------"
    for environment in $(btp --format json list accounts/environment-instance -sa $1 | jq -r '.environmentInstances[] | @base64'); do
        name_slug="$(_jq $environment '.serviceName')-$(_jq $environment '.name')"
        echo "# terraform code for $name_slug environment instance"
        echo "resource \"btp_subaccount_environment_instance\" \"$name_slug\" {"
        echo "  environment_type = \"$(_jq $environment '.environmentType')\""
        echo "  name             = \"$(_jq $environment '.name')\""
        echo "  plan_name        = \"$(_jq $environment '.planName')\""
        echo "  service_name     = \"$(_jq $environment '.serviceName')\""
        echo "  subaccount_id    = btp_subaccount.$sa_name.id"
        parameters=$(_jq $environment '.parameters')
        [ "$parameters" != "null" ] && echo "  parameters       = \"$(echo $parameters | sed "s/\"/\\\\\"/g")\""
        landscape_label=$(_jq $environment '.landscapeLabel')
        [ "$landscape_label" != "null" ] && echo "  landscape_label  = \"$landscape_label\""
        echo "}"
        echo "# Command to import the state of $name_slug environment instance"
        echo "# terraform import btp_subaccount_environment_instance.$name_slug $1,$(_jq $environment '.id')"
        echo ""
    done
}

case $1 in
    -h | --help)
        _usage
        ;;
    -v | --version)
        _version
        ;;
    -sa | --subaccount)
        if [ -z $2 ]; then
            echo "The subaccount GUID is missing."
            exit 1
        fi
        _generate_tf_code_for_environment $2
        ;;
    -all)
        exit
        ;;
    *)
        _usage
        ;;
esac

