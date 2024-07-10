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

# Check if the appname, env, and action arguments are provided
if [ -z "$3" ]; then
  echo "Usage: $0 <appname> <environment(s, comma separated list)> <action (pauseIU|resumeIU)>
allowed_environments=("dev" "qa" "prod" "perf" "uat")
examples:
  $0 myapp dev pauseIU
  $0 anotherapp dev,qa resumeIU
  $0 someotherapp perf,prod,uat pauseIU
Avoid SPACES in all arguments"
  exit 1
fi

# Assign the arguments to variables
appname="$1"
env_list="$2"
action="$3"

# Check if the action is either pauseIU or resumeIU
if [[ "$action" != "pauseIU" && "$action" != "resumeIU" ]]; then
  echo "Error: Action must be either 'pauseIU' or 'resumeIU'."
  exit 1
fi

# Determine the appropriate file based on the action
if [ "$action" == "pauseIU" ]; then
  action_file="pause-image-updater.yaml"
else
  action_file="resume-image-updater.yaml"
fi

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

  if [ ! -d "apps-helm-chart/$appname" ]; then
    echo "The folder apps-helm-chart/$appname does not exist."
    #echo "Please run:"
    echo "creating apps-helm-chart/$appname"
    #echo "Please make sure that this folder contains apps-helm-chart/$appname/$appname-values.yaml and apps-helm-chart/$appname/$env-$appname-values.yaml"
    #mkdir -p apps-helm-chart/$appname
  else
    echo "The folder apps-helm-chart/$appname already exists."
  fi

  if [ ! -f "apps-helm-chart/$appname/$appname-values.yaml" ]; then
    echo "The file apps-helm-chart/$appname/$appname-values.yaml does not exist."
    echo creating file apps-helm-chart/templates/mbe/dev-mbe-app.yaml
    #echo "Please create this file:"
    echo "appname: $appname" > apps-helm-chart/$appname/$appname-values.yaml
    sed  "s/APPNAME/$appname/g" apps-helm-chart/example/values.yaml > apps-helm-chart/$appname/$appname-values.yaml
  else
    echo "The file apps-helm-chart/$appname/$appname-values.yaml exists."
  fi

  if [ ! -f "apps-helm-chart/$appname/$env-$appname-values.yaml" ]; then
    echo "The file apps-helm-chart/$appname/$env-$appname-values.yaml does not exist."
    echo creating file apps-helm-chart/$appname/$env-$appname-values.yaml
    #echo "Please create this file:"
    echo "appname: $appname" > apps-helm-chart/$appname/$env-$appname-values.yaml
    sed  "s/APPNAME/$appname/g" apps-helm-chart/example/$env-values.yaml > apps-helm-chart/$appname/$env-$appname-values.yaml
  else
    echo "The file apps-helm-chart/$appname/$env-$appname-values.yaml exists."
  fi
 
  ./create-annotations.sh $appname $dev

  helm template apps-helm-chart \
    -f apps-helm-chart/values.yaml \
    -f apps-helm-chart/"$env"-values.yaml \
    -f apps-helm-chart/"$appname"/"$appname"-values.yaml \
    -f apps-helm-chart/"$appname"/"$env"-"$appname"-values.yaml \
    -f apps-helm-chart/"$appname"/"$action_file" \
    --set appname="$appname" \
    --show-only  templates/app.yaml > apps-helm-chart/templates/"$appname"/"$env"-"$appname"-app.yaml

  echo "App YAML created at apps-helm-chart/templates/"$appname"/"$env"-"$appname"-app.yaml "
  #cat appofapps/"$appname"/"$env"-"$appname"-app.yaml
done

echo Checking if the app is ready to be added to git
./check-app-repo-path-branch.sh apps-helm-chart/templates/"$appname"/"$env"-"$appname"-app.yaml || exit 1

echo checking dry-run of kubectl apply
kubectl apply -f apps-helm-chart/templates/"$appname"/"$env"-"$appname"-app.yaml --dry-run=client

   
