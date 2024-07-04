This chart is for devops team and argocd admins


projects folder contains the projects created for each environment, need to apply them once per argocd instance
projects-helm-chart folder contains the helm chart project templates ( yaml files ), need to use them if there are news projects to be created, create a new values.yaml
 
apps folder contains all the apps created, need to apply them for each app
apps-helm-chart folder contains the helm chart for any application for all environemnts, to be run once per application







