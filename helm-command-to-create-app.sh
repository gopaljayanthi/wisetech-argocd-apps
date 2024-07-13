#!/bin/bash

usage() {
  echo "Usage: $0 <appname> <environment(s, comma separated list)> [<action (pauseIU|resumeIU)>]"
  echo "allowed_environments=(${allowed_environments[*]})"
  echo "examples:"
  echo "  $0 myapp dev"
  echo "  $0 anotherapp dev,qa resumeIU"
  echo "  $0 someotherapp perf,prod,uat pauseIU"
  echo "Avoid SPACES in all arguments"
  exit 1
}
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

############################################# main#####################

# Check if the appname, env, and action arguments are provided
if [ -z "$1" ] || [ -z "$2" ]; then
  usage
  exit 1
fi

# Assign the arguments to variables
appname="$1"
env_list="$2"
action=$3

IFS=',' read -r -a env_array <<< "$env_list"

if ! command -v yq &> /dev/null; then
    echo "Error: yq (YAML processor) is required but not installed."
    echo "Please install yq before running this script."
    exit 1
fi

# Define the allowed list of environments
allowed_environments=("dev" "qa" "prod" "perf" "uat")
# Allowed actions
allowed_actions=("pauseIU" "resumeIU")


# If the action argument is provided, check if it is valid
if [ -n "$action" ]; then
  #action=$3
  if [[ ! " ${allowed_actions[@]} " =~ " ${action} " ]]; then
    echo "Invalid action: $action"
    usage
  fi
else
  action="default_action" # Set your default action here if needed
fi

echo preparing ...........................................................
IFS=',' read -r -a env_array <<< "$env_list"
echo making folder with name $appname
   mkdir -p apps-helm-chart/templates/"$appname"
   mkdir -p appofapps/"$appname"
######################################## for first time apps ##############################################
 if [ ! -d "apps-helm-chart/$appname" ]; then
    echo "The folder apps-helm-chart/$appname does not exist."
    #echo "Please run:"
    echo "creating apps-helm-chart/$appname"
    #echo "Please make sure that this folder contains apps-helm-chart/$appname/$appname-values.yaml and apps-helm-chart/$appname/$env-$appname-values.yaml"
    mkdir -p apps-helm-chart/$appname
    echo "The file apps-helm-chart/$appname/$appname-values.yaml does not exist."
    echo creating file apps-helm-chart/templates/mbe/dev-mbe-app.yaml
    #echo "Please create this file:"
    sed  "s/APPNAME/$appname/g" apps-helm-chart/example/values.yaml > apps-helm-chart/$appname/$appname-values.yaml
    echo ------getting annotations-----------

../wisetech-k8s-repo/create-image-updater-annotation.sh ../wisetech-k8s-repo/$appname-mainchart/dev/values.yaml $appname
annotationFile=./$appname-annotations.yaml
FILE_PATH="$annotationFile"
sleep 3
# Check if the file does not exist
if [ ! -f "$FILE_PATH" ]; then
    echo "File '$FILE_PATH' not found."
    exit 1
fi
# Continue with the script if the file exists
echo "File '$FILE_PATH' exists."

appnameValuesFile=apps-helm-chart/$appname/$appname-values.yaml
iuRegexpFile=apps-helm-chart/templates/$appname/image-updater-regexp.txt

cat $annotationFile | grep ^metadata: > $iuRegexpFile
cat $annotationFile | grep annotations: >> $iuRegexpFile
cat $annotationFile | grep regexp >> $iuRegexpFile

cat $annotationFile | grep ^metadata: >> $appnameValuesFile
cat $annotationFile | grep annotations: >> $appnameValuesFile
cat $annotationFile | grep image-list >> $appnameValuesFile
cat $annotationFile | grep image-name >> $appnameValuesFile
cat $annotationFile | grep update-strategy >> $appnameValuesFile
cat $annotationFile | grep image-tag >> $appnameValuesFile
cat $annotationFile | grep ignore-tags >> $appnameValuesFile

cat $annotationFile | grep ^metadata: > apps-helm-chart/$appname/resume-image-updater.yaml
cat $annotationFile | grep annotations: >> apps-helm-chart/$appname/resume-image-updater.yaml
cat $annotationFile | grep ignore-tags >> apps-helm-chart/$appname/resume-image-updater.yaml
sed 's/somethingorother/"*"/g' ultimate-apps-helmchart/mbe/resume-image-updater.yaml > apps-helm-chart/$appname/pause-image-updater.yaml

    #./create-annotations.sh $appname dev
    for env in "${allowed_environments[@]}"; do
     echo creating the $env specific values yaml for app $appname
     sed  "s/APPNAME/$appname/g" apps-helm-chart/example/$env-values.yaml > apps-helm-chart/$appname/$env-$appname-values.yaml
     helm template apps-helm-chart \
     -f apps-helm-chart/values.yaml \
     -f apps-helm-chart/$env-values.yaml \
     -f $appnameValuesFile \
     -f apps-helm-chart/$appname/$env-$appname-values.yaml  \
     -s templates/$appname/image-updater-regexp.txt \
     | sed '/^#/d' | sed '/---/d' >> apps-helm-chart/$appname/$env-$appname-values.yaml
    done
  else
    echo "The folder apps-helm-chart/$appname already exists. skipping annotaion for image updater"
  fi


#exit 0
echo Loop over each environment value

# Split the comma-separated list into an array

for env in "${env_array[@]}"; do
  # Check if the environment is allowed
  if ! is_env_allowed "$env"; then
    echo "Error: Environment '$env' is not allowed."
    echo 'allowed_environments=("dev" "qa" "prod" "perf" "uat")'
    continue  # Skip processing this environment
  fi
  echo
  echo "Environment '$env'"
  appFile=appofapps/"$appname"/"$env"-"$appname"-app.yaml

# Determine the appropriate file based on the action
if [ "$action" == "pauseIU" ]; then
  action_cmd="pause-image-updater.yaml"
else
if [ "$action" == "resumeIU" ]; then
  action_cmd="resume-image-updater.yaml"
else
  action_cmd=""$env"-"$appname"-values.yaml"
fi
fi

echo action_cmd is $action_cmd you see

  # Generate YAML using Helm template
  helm template apps-helm-chart \
    -f apps-helm-chart/values.yaml \
    -f apps-helm-chart/"$env"-values.yaml \
    -f apps-helm-chart/"$appname"/"$appname"-values.yaml \
    -f apps-helm-chart/"$appname"/"$env"-"$appname"-values.yaml \
    -f apps-helm-chart/"$appname"/"$action_cmd" \
    --set appname="$appname" \
    --show-only  templates/app.yaml > $appFile

  echo "App YAML created at $appFile, see yaml below "
  cat appofapps/"$appname"/"$env"-"$appname"-app.yaml
done

echo Checking if the app is ready to be added to git
./check-app-repo-path-branch.sh $appFile || exit 1

echo checking dry-run of kubectl apply
kubectl apply -f $appFile --dry-run=client

# Check if the previous command failed
if [ $? -ne 0 ]; then
    echo "The command kubectl apply -f command failed."
    echo "Check the file $appFile for issues"

    exit 1
fi

echo run: kubectl apply -f $appFile
  
   
