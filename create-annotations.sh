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
  echo "Usage: $0 <appname> <environment>
 allowed_environments=("dev" "qa" "prod" "perf" "uat")
 example
  $0 myapp dev
  Avoid SPACES in all arguments"
  exit 1
fi

# Assign the first argument to a variable
appname="$1"
env="$2"

#mkdir -p apps-helm-chart/$appname

../wisetech-k8s-repo/create-image-updater-annotation.sh ../wisetech-k8s-repo/$appname-mainchart/$env/values.yaml $appname
annotationFile=./$appname-annotations.yaml
FILE_PATH="$annotationFile"

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


#create this first

