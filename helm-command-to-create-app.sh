#!/bin/bash

usage() {
  echo
  echo "Usage: $0 <appname> <environment(s, comma separated list)> [<action (pauseIU|resumeIU)>]"
  echo "allowed_environments=(${allowed_environments[*]})"
  echo "examples:"
  echo "  $0 myapp dev"
  echo "  $0 anotherapp dev,qa resumeIU"
  echo "  $0 someotherapp perf,prod,uat pauseIU"
  echo "Avoid SPACES in all arguments"
  echo " - needs kubectl, helm and yq to work"
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

############################################# main #####################

# Check if the appname, env, and action arguments are provided
if [ -z "$1" ] || [ -z "$2" ]; then
echo
echo error: takes two arguments and optional third argument
echo
  usage
fi

# Assign the arguments to variables
appname="$1"
env_list="$2"
action=$3

    ######################### Doing CHECKS ######################################

if [[ ! "$appname" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$ ]]; then
  echo "Invalid appname: $appname , must start with lowercase alphabet or number, 
     should contain only 
      lowercase alphabet, NO UPPERCASE,
      numbers 
      hyphens allowed in the middle, NOT IN THE BEGINNING OR END"
  exit 1
fi

appname_length=${#appname}
echo the $appname is $appname_length characters long

# Check if the length is greater than 48 characters
if [ "$appname_length" -gt 48 ]; then
  echo "Error: appname is longer than 48 characters."
  exit 1
fi

# Define the allowed list of environments
allowed_environments=("dev" "qa" "prod" "perf" "uat")
# Allowed actions
allowed_actions=("pauseIU" "resumeIU")
# Split the comma-separated list into an array
IFS=',' read -r -a env_array <<< "$env_list"
for env in "${env_array[@]}"; do
  # Check if the environment is allowed
  if ! is_env_allowed "$env"; then
    echo "Error: Environment '$env' is not allowed."
    echo 'allowed_environments=("dev" "qa" "prod" "perf" "uat")'
    exit 1
  fi
  echo
done

if ! command -v yq &> /dev/null; then
    echo "Error: yq (YAML processor) is required but not installed."
    echo "Please install yq before running this script."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "Error: yq (YAML processor) is required but not installed."
    echo "Please install kubectl before running this script."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "Error: yq (YAML processor) is required but not installed."
    echo "Please install kubectl before running this script."
    exit 1
fi

# If the action argument is provided, check if it is valid
if [ -n "$action" ]; then
  #action=$3
  if [[ ! " ${allowed_actions[@]} " =~ " ${action} " ]]; then
    echo "Invalid action: $action"
    echo WARNING: skipping to default action, allowed actions are pauseIU and resumeIU
  fi
else
  action="default_action" # Set your default action here if needed
fi
####################################################################### FINISHED CHECKING ##############
echo preparing ...........................................................
echo making folder with name $appname
   chartFolder=apps-helm-chart
   templatesFolder=$chartFolder/templates/"$appname"
   valuesFolder=$chartFolder/"$appname"
   aofaFolder=appofapps/"$appname"
   appValuesFile=$valuesFolder/$appname-values.yaml

   mkdir -p $templatesFolder
   mkdir -p $aofaFolder
######################################## for first time apps ##############################################
 if [ ! -d $valuesFolder ]; then
    echo "The folder $valuesFolder does not exist."
    #echo "Please run:"
    echo "creating $valuesFolder "
    mkdir -p $valuesFolder
    echo "The file $appValuesFile does not exist."
    echo creating file $templatesFolder/mbe/dev-mbe-app.yaml
    #echo "Please create this file:"
    sed  "s/APPNAME/$appname/g" $chartFolder/example/values.yaml > $appValuesFile
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

appnameValuesFile=$appValuesFile
iuRegexpFile=$templatesFolder/image-updater-regexp.txt

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

cat $annotationFile | grep ^metadata: > $valuesFolder/resume-image-updater.yaml
cat $annotationFile | grep annotations: >> $valuesFolder/resume-image-updater.yaml
cat $annotationFile | grep ignore-tags >> $valuesFolder/resume-image-updater.yaml
sed 's/somethingorother/"*"/g' ultimate-apps-helmchart/mbe/resume-image-updater.yaml > $valuesFolder/pause-image-updater.yaml

    for env in "${allowed_environments[@]}"; do
     echo creating the $env specific values yaml for app $appname
     envAppValuesFile=$valuesFolder/$env-$appname-values.yaml
     sed  "s/APPNAME/$appname/g" $chartFolder/example/$env-values.yaml > $envAppValuesFile
     helm template $chartFolder \
     -f $chartFolder/values.yaml \
     -f $chartFolder/$env-values.yaml \
     -f $appValuesFile \
     -f $envAppValuesFile  \
     -s templates/$appname/image-updater-regexp.txt \
     | sed '/^#/d' | sed '/---/d' >> $envAppValuesFile
    done
  else
    echo "The folder $valuesFolder already exists. skipping annotaion for image updater"
  fi


######################################## end of first time apps ##############################################

echo Loop over each environment value
for env in "${env_array[@]}"; do
envAppValuesFile=$valuesFolder/$env-$appname-values.yaml
  echo "Environment '$env'"
  appFile=$aofaFolder/"$env"-"$appname"-app.yaml

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
  helm template $chartFolder \
    -f $chartFolder/values.yaml \
    -f $chartFolder/"$env"-values.yaml \
    -f $appValuesFile \
    -f $envAppValuesFile \
    -f $valuesFolder/"$action_cmd" \
    --set appname="$appname" \
    --show-only  templates/app.yaml > $appFile

if [ $? -ne 0 ]; then
    echo "The command helm template -f command failed."
    echo "Check the values files in $valuesFolder for issues"
    exit 1
fi

  if [ ! -f "$appFile" ]; then
    echo "The file $appFile does not exist."
    check helm template command for issues or missing/misconfigured values files below
    echo "
      $chartFolder/values.yaml 
      $chartFolder/"$env"-values.yaml 
      $valuesFolder/"$appname"-values.yaml 
      $valuesFolder/"$env"-"$appname"-values.yaml
      $valuesFolder/"$action_cmd" "

    exit 1
  else
    echo "The file $appValuesFile exists."
  fi

echo
  echo "App YAML created at $appFile, see yaml below "
  cat $appFile
echo

echo Checking if the app has the source repo and path valid
./check-app-repo-path-branch.sh $appFile || exit 1
echo SUCCESS: the repo and path are both accessible

echo checking dry-run of kubectl apply
kubectl apply -f $appFile --dry-run=client

# Check if the previous command failed
if [ $? -ne 0 ]; then
    echo "The command kubectl apply -f command failed."
    echo "Check the file $appFile for issues"
    exit 1
fi

echo run: kubectl apply -f $appFile
echo
done
############################################################### end of loop ##################

  
   
