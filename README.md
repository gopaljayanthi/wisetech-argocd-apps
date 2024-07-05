This chart is for devops team and argocd admins

Use wisetech branch for wisetech customer

projects folder contains the projects created for each environment, need to apply them once per argocd instance
projects-helm-chart folder contains the helm chart project templates ( yaml files ), need to use them if there are news projects to be created, create a new values.yaml
 
appofapps folder contains all the apps created, need to apply them for each app
apps-helm-chart folder contains the helm chart for any application for all environemnts, to be run once per application

ONE_TIME_STARTUP_STEPS
kubectl apply -f projects/
kubectl apply -f appofapps.yaml

helm-command-to-create-app.sh will take <appname> and <environment> as inputs, to create an app.yaml which is created in appofapps/<appname> folder 









