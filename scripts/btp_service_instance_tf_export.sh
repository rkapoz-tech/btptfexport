#!/bin/bash
# This script is used to generate the import statements for the resources on BTP into terraform code and terraform state.
# It`s necessary to btp-cli installed and configured to use this script.
# Author: Danilo Bovo <bovodanilo@gmail.com>
# Version: 1.0
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

_generate_tf_code_for_service_instance() {
    echo "data \"btp_subaccount_service_offerings\" \"all\" {"
    echo "  subaccount_id = \"$1\""
    echo "}"
    echo "# ------------------------------------------------------------------------------------------------------"
    echo "# Creation of subaccount service instance"
    echo "# It's necessary to check the parameters and if it's possible to import the service instance, as documented in the following link:"
    echo "# https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_service_instance#restriction"
    echo "# ------------------------------------------------------------------------------------------------------"
    # Generate the terraform code for the subaccount with the given GUID
    for service_instance in $(btp --format json list services/instance -sa $1 | jq -r '.[] | @base64'); do
        name_slug="$(_jq $service_instance '.name')"
        id="$(_jq $service_instance '.id')"
        instances_retrievable=$(btp --format json get services/offering $(btp get services/plan $(btp get services/instance $id | awk '/^service_plan_id:/ { print $NF }') | awk '/^service_offering_id:/ { print $NF }') | jq '.instances_retrievable')
        if [ "$instances_retrievable" == "false" ]; then
            echo "# The service instance $name_slug is not possible to import the state."
            continue
        fi
        parameters=$(btp --format json get services/instance $id --subaccount $1 --show-parameters)
        echo "# terraform code for $name_slug service instance"
        echo "resource \"btp_subaccount_service_instance\" \"$name_slug\" {"
        echo "  subaccount_id    = data.btp_subaccount_service_offerings.all.subaccount_id"
        echo "  serviceplan_id   = \"$(_jq $service_instance '.service_plan_id')\""
        echo "  name             = \"$name_slug\""
        # labels=$(_jq $service_instance '.labels')
        # [ "$labels" != "null" ] && echo "  labels           = {"
        # echo "$(echo $labels | tr -d " " | sed -r "s/([^=]*)=([^;]*);?/    \1 = [\"\2\"]\n/g;")"
        # echo "  }"
        [ "$parameters" != "null" ] && [ "$parameters" != "" ] && echo "  parameters       = \"$(echo $parameters | sed "s/\"/\\\\\"/g")\""
        echo "}"
        echo "# Command to import the state of $name_slug service instance"
        echo "# terraform import btp_subaccount_service_instance.$name_slug $1,$(_jq $service_instance '.id')"
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
        _generate_tf_code_for_service_instance $2
        ;;
    -all)
        exit
        ;;
    *)
        _usage
        ;;
esac

