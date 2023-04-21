# Preparation Steps

## Create new IBM Cloud Resource Group
As Account Owner create an IBM Cloud Resource Group in the account management, in our example and screenshots we use "mvi-on-sat"

## Create Access Group and access permissions
* Create an IAM Access Group "mvi-on-sat"
* Attach as many users you need to that Group
* Assign the following permissions from the screenshot
![](images/iam-access-permissions.png)

## Create an IAM Service ID for Deployment
* Create an IAM Service ID with the name "sat-deployer"
* Assign the Service ID to the access group "mvi-on-sat"
* Create and save an API Key for that Service ID, this will be our IBM_CLOUD_API_KEY key for deployment

## Create an IAM Service ID for OpenShift Data Foundation (ODF)
* Create an IAM Service ID "odf-local"
* Give the Service ID the following permissions
![](images/odf-service.id.png)
* create and save an API Key for that Service ID, this will be used to deploy OpenShift Data Foundation using IBM Cloud Satellite storage templates.

## Domain Requirements Cloud Internet Services (CIS)
* You need to have configured Cloud Internet Services including a public custom domain
* We will use that CIS Instance for Maximo/MVI to create Domain DNS entries and Letsencrypt certificates.
* You could share that CIS instance when deploying multiple environments, because each environment gets its own subdomain
* Create a Service ID "cis" and give it the following permissions for your cis instance:
![](images/cis-service-id.png)
* Create and save an API Key for that service ID, we need that key later to create automatically DNS entries during Maximo setup

