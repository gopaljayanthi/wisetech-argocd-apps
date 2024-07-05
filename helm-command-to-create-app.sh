#!/bin/bash
# Check if a folder argument is provided
if [ -z "$2" ]; then
  echo "Usage: $0 <appname> <environment>"
  exit 1
fi


# Check if the second argument is provided
if [ -z "$2" ]; then
  echo "Error: No environment provided."
  exit 1
fi
# List of valid environments
valid_environments=("dev" "qa" "per" "uat" "prod")
# Check if the second argument is in the list of valid environments
if [[ ! " ${valid_environments[@]} " =~ " $2 " ]]; then
  echo "Error: Invalid environment '$2'. Valid environments are: ${valid_environments[*]}."
  exit 1
fi
echo "Environment '$2' is valid."

# Assign the first argument to a variable
appname="$1"
env="$2"

#helm template apps-helm-chart
mkdir -p appofapps/"$appname"/
helm template apps-helm-chart -f apps-helm-chart/values.yaml -f apps-helm-chart/"$env"-values.yaml --set appname="$appname" > appofapps/"$appname"/"$env"-"$appname"-app.yaml

echo app yaml created at appofapps/"$appname"/"$env"-"$appname"-app.yaml
cat appofapps/"$appname"/"$env"-"$appname"-app.yaml
