#!/bin/bash

# Check if the required argument is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <comma-separated-app-names>"
  exit 1
fi

# Input provided as comma-separated values
input=$1

# Split the input into an array
IFS=',' read -r -a apps <<< "$input"

# Create a temporary YAML file
tmpfile=$(mktemp /tmp/apps.XXXXXX.yaml)

# Start creating the YAML structure
yq eval '{
  metadata: {
    annotations: {
      "argocd-image-updater.argoproj.io/write-back-method": "git:secret:argocd/git-creds",
      "argocd-image-updater.argoproj.io/git-branch": "master",
      "notifications.argoproj.io/subscribe.on-deployed.github": "maonchart-qa-on-deployed"
    }
  }
}' --null-input > "$tmpfile"

# Add image list
image_list="argocd-image-updater.argoproj.io/image-list: "
for app in "${apps[@]}"; do
  image_list+="$app=docker.io/gopalvithaljayanthi/nginx,"
done
image_list=${image_list%,}  # Remove the trailing comma
yq eval ".metadata.annotations.\"$image_list\"" -i "$tmpfile"

# Add entries for each app
for app in "${apps[@]}"; do
  yq eval ".metadata.annotations.\"argocd-image-updater.argoproj.io/$app.allow-tags\" = \"regexp:^{{ .Values.branch }}\"" -i "$tmpfile"
  yq eval ".metadata.annotations.\"argocd-image-updater.argoproj.io/$app.update-strategy\" = \"latest\"" -i "$tmpfile"
  yq eval ".metadata.annotations.\"argocd-image-updater.argoproj.io/$app.helm.image-name\" = \"$app.image.name\"" -i "$tmpfile"
  yq eval ".metadata.annotations.\"argocd-image-updater.argoproj.io/$app.helm.image-tag\" = \"$app.image.tag\"" -i "$tmpfile"
done

# Output the final YAML file
mv "$tmpfile" apps.yaml

echo "YAML file created: apps.yaml"
