#!/bin/bash
################################################ functions #######################
usage() {
  echo
  echo "Usage: $0 <appname> <environment(s, comma separated list)> [<action (pauseIU|resumeIU|createIU)>]"
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
# Function to check if folder exists in the repo at the specified branch and path
function folder_exists_in_repo {
    local repoURL="$1"
    local branch="$2"
    local path="$3"

    # Clone the repository to a temporary directory
    temp_dir=$(mktemp -d)
    echo using tempdir $temp_dir
    if [ "$branch" == "HEAD" ]; then
        git clone "$repoURL" "$temp_dir" >/dev/null 2>&1
    else
        git clone --branch "$branch" "$repoURL" "$temp_dir" >/dev/null 2>&1
    fi

    # Navigate to the directory
    cd "$temp_dir" || return 1

    # Check if the path exists in the repo
    if ls "$path" >/dev/null; then
        echo "Folder '$path' exists in branch '$branch' of the repository."
##COMMENT BELOW LINE TO DEBUG
        rm -rf "$temp_dir"
        return 0
    else
        echo "Folder '$path' does not exist in branch '$branch' of the repository."
##COMMENT BELOW LINE TO DEBUG
        rm -rf "$temp_dir"
        return 1
    fi
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

#########################           Doing CHECKS                 ######################################

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
allowed_actions=("pauseIU" "resumeIU" "createIU")
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
    echo "Error: yq is required but not installed."
    echo "Please install yq before running this script."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is required but not installed."
    echo "Please install kubectl before running this script."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "Error: helm is required but not installed."
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
   currentWorkingFolder=$(PWD)
   chartFolder=apps-helm-chart
   templatesFolder=$chartFolder/templates/"$appname"
   valuesFolder=$chartFolder/"$appname"
   aofaFolder=appofapps/"$appname"
   appValuesFile=$valuesFolder/$appname-values.yaml

echo making folder with name $templatesFolder $aofaFolder
   mkdir -p $templatesFolder
   mkdir -p $aofaFolder
######################################## for first time apps ##############################################
 if [ ! -d $valuesFolder ]; then
    echo "The folder $valuesFolder does not exist."
    echo "creating $valuesFolder "
    mkdir -p $valuesFolder
    echo "The file $appValuesFile does not exist."
    echo creating file $appValuesFile
    sed  "s/APPNAME/$appname/g" $chartFolder/example/values.yaml > $appValuesFile
    echo ------getting annotations-----------
        for env in "${allowed_environments[@]}"; do
          echo creating the $env specific values yaml for app $appname
          envAppValuesFile=$valuesFolder/$env-$appname-values.yaml
          sed  "s/APPNAME/$appname/g" $chartFolder/example/$env-values.yaml > $envAppValuesFile
       done
  else
    echo "The folder $valuesFolder already exists. skipping copying from example folder $chartFolder/example"
  fi
######################################## end of first time apps ##############################################
########################################for annotations########################################
if [ "$action" == "createIU" ]; then
    echo "adding image updater annotations"
../wisetech-k8s-repo/create-image-updater-annotation.sh ../wisetech-k8s-repo/$appname-mainchart/dev/values.yaml $appname
annotationFile=./$appname-annotations.yaml
sleep 3
# Check if the file does not exist
if [ ! -f "$annotationFile" ]; then
    echo "error: File '$annotationFile' not found. check the script ../wisetech-k8s-repo/create-image-updater-annotation.sh or file ../wisetech-k8s-repo/$appname-mainchart/dev/values.yaml "
    exit 1
fi
# Continue with the script if the file exists
echo "File $annotationFile exists."

iuRegexpFile=$templatesFolder/image-updater-regexp.txt

grep ^metadata: $annotationFile > $iuRegexpFile
grep annotations: $annotationFile >> $iuRegexpFile
grep regexp $annotationFile >> $iuRegexpFile

grep ^metadata: $annotationFile >> $appValuesFile
grep annotations: $annotationFile >> $appValuesFile
grep image-list $annotationFile >> $appValuesFile
grep image-name $annotationFile >> $appValuesFile
grep update-strategy $annotationFile >> $appValuesFile
grep image-tag $annotationFile >> $appValuesFile
grep ignore-tags $annotationFile >> $appValuesFile

grep ^metadata: $annotationFile > $valuesFolder/resume-image-updater.yaml
grep annotations: $annotationFile >> $valuesFolder/resume-image-updater.yaml
grep ignore-tags $annotationFile >> $valuesFolder/resume-image-updater.yaml

sed 's/somethingorother/"*"/g' $valuesFolder/resume-image-updater.yaml > $valuesFolder/pause-image-updater.yaml

    for env in "${allowed_environments[@]}"; do
     echo creating the $env specific values yaml for app $appname
     envAppValuesFile=$valuesFolder/$env-$appname-values.yaml
     helm template $chartFolder \
     -f $chartFolder/values.yaml \
     -f $chartFolder/$env-values.yaml \
     -f $appValuesFile \
     -f $envAppValuesFile  \
     -s templates/$appname/image-updater-regexp.txt \
     | sed '/^#/d' | sed '/---/d' >> $envAppValuesFile
    done
fi
########################## end of checks if action is pauseIU or resumeIU for adding ImageUodater annotations ##################################################
echo
echo Loop over each environment value
for env in "${env_array[@]}"; do
  envAppValuesFile=$valuesFolder/$env-$appname-values.yaml
  echo "Environment '$env'"
  appFile=$aofaFolder/"$env"-"$appname"-app.yaml

# Determine the appropriate file based on the action for enabling/disabling image updater
if [ "$action" == "pauseIU" ]; then
  action_cmd="pause-image-updater.yaml"
else
if [ "$action" == "resumeIU" ]; then
  action_cmd="resume-image-updater.yaml"
else
  action_cmd=""$env"-"$appname"-values.yaml"
fi
fi
echo
echo generating app yaml from helm tamplates and values
echo
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
    echo check helm template command for issues or missing/misconfigured values files below
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

################################################################## pre-deployment checks ########################
echo Checking if the app has valid source repo branch and path 
#./check-app-repo-path-branch.sh $appFile
# Read YAML file and extract repoURL, branch, and path
repoURL=$(yq e '.spec.source.repoURL' "$appFile")
targetRevision=$(yq e '.spec.source.targetRevision' "$appFile")
path=$(yq e '.spec.source.path' "$appFile")

echo "Testing $repoURL $targetRevision $path"

# Determine the branch to use (handling "HEAD" case)
if [ "$targetRevision" == "HEAD" ]; then
    branch="master"  # Default to master branch (or specify another default branch)
    #branch="main"  # Default to master branch (or specify another default branch)
else
    branch="$targetRevision"
fi

if folder_exists_in_repo "$repoURL" "$branch" "$path"; then
    echo "Folder exists!"
        echo "you can create this application now,
 by git add/commit/push"
else
    echo "Folder does not exist."
    echo "The script to check if paths exist in the source repo failed. one of these is wrong "$repoURL" "$branch" "$path""
    echo "Check the files $appValuesFile $envAppValuesFile for issues"
    echo do not create this application yet
    exit 1
fi
echo SUCCESS: the repo and path are both accessible
echo checking dry-run of kubectl apply
cd $currentWorkingFolder
kubectl apply -f ./"$appFile" --dry-run=client

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