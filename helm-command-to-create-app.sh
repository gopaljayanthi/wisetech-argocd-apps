#!/bin/bash

# Define the allowed list of environments
allowed_environments=("dev" "qa" "prod" "perf" "uat")

# Function to check if an environment is allowed
function is_env_allowed {
    local env=$1
    for allowed_env in "${allowed_environments[@]}"; do
        if [[ "$env" == "$allowed_env" ]]; then
            return 0  # Environment is allowed
        fi
    done
    return 1  # Environment is not allowed
}

# Check if a appname and env arguments are provided
if [ -z "$2" ]; then
  echo "Usage: $0 <appname> <environment(s, comma sepearated list)>
 allowed_environments=("dev" "qa" "prod" "perf" "uat")
 examples
  $0 myapp dev
  $0 anotherapp dev,qa
  $0 someotherapp perf,prod,uat
  Avoid SPACES in all arguments"
  exit 1
fi

# Assign the first argument to a variable
appname="$1"
env_list="$2"

  # Create directories if needed
  #mkdir -p appofapps/"$appname"/

# Split the comma-separated list into an array
IFS=',' read -r -a env_array <<< "$env_list"

# Loop over each environment value
for env in "${env_array[@]}"; do
  # Check if the environment is allowed
  if ! is_env_allowed "$env"; then
    echo "Error: Environment '$env' is not allowed."
    echo 'allowed_environments=("dev" "qa" "prod" "perf" "uat")'
    continue  # Skip processing this environment
  fi
   echo
    echo "Environment '$env'"
  # Generate YAML using Helm template
    mkdir -p apps-helm-chart/templates/"$appname"
    mkdir -p apps-helm-chart/"$appname"
    touch apps-helm-chart/"$appname"/"$appname"-values.yaml
    touch apps-helm-chart/"$appname"/"$env"-"$appname"-values.yaml
 helm template apps-helm-chart -f apps-helm-chart/values.yaml \
-f apps-helm-chart/"$env"-values.yaml \
-f apps-helm-chart/"$appname"/"$appname"-values.yaml \
-f apps-helm-chart/"$appname"/"$env"-"$appname"-values.yaml \
--set appname="$appname" \
--show-only  templates/app.yaml > apps-helm-chart/templates/"$appname"/"$env"-"$appname"-app.yaml

  echo "App YAML created at apps-helm-chart/templates/"$appname"/"$env"-"$appname"-app.yaml "
  #cat appofapps/"$appname"/"$env"-"$appname"-app.yaml
done

#echo Checking if the app is ready to be added to git
#./check-app-repo-path-branch.sh apps-helm-chart/templates/"$appname"/"$env"-"$appname"-app.yaml

echo run git status verify apps-helm-chart/templates/"$appname"/"$env"-"$appname"-app.yaml


