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

## Custom Domain Registration
It's recommended to have your custom domain ready before you start with setting up your cluster since it might take up to 24 hours to have your domain configurations verified.<br>
To create a custom domain, first you will need to register a new domain with domain name registration service.
- From the menu on IBM Cloud console, go to Classic infrastructure > Services > Domain Registration.
<img width="650" alt="Screenshot 2023-04-14 at 2 37 33 PM" src="https://media.github.ibm.com/user/265755/files/2427bb26-a808-484c-b362-720f9f2731f0">

- Enter the new domain name in the <b>Domain Name</b> field. Click the <b>Check Availability</b> button to check whether the domain name is available, then click continue to register the domain.
<img width="1212" alt="Screenshot 2023-04-14 at 2 52 14 PM" src="https://media.github.ibm.com/user/265755/files/c6ee2812-3922-4d14-aebd-56adac49545a">

- Unlock the domain.
<img width="1196" alt="Screenshot 2023-04-14 at 3 07 05 PM" src="https://media.github.ibm.com/user/265755/files/25f585ad-e1d9-4e70-bd9b-37e0106b7d92">

- From the catalog, search for “internet services” and create free trial or standard service. 
<img width="1242" alt="image" src="https://media.github.ibm.com/user/265755/files/1a518a84-bd7a-412e-98a5-cc44395f23d3">

- Click on Add domain
<img width="700" alt="Screenshot 2023-04-14 at 3 50 34 PM" src="https://media.github.ibm.com/user/265755/files/c6a61b63-15a7-4abd-8d5f-e7947f636999">

- Add your custom domain name.
<img width="404" alt="Screenshot 2023-04-14 at 3 50 54 PM" src="https://media.github.ibm.com/user/265755/files/1e318e40-f53c-4336-bb35-d6aedfda2e9d">

- Keep note of the CRN and name servers.
<img width="1512" alt="Screenshot 2023-04-14 at 3 52 24 PM" src="https://media.github.ibm.com/user/265755/files/d6672004-9b98-453d-aeec-577f73bfeeb9">

- Go back to the domain registration page and replace the name servers with the new ones and associate them to your custom domain.
<img width="631" alt="Screenshot 2023-04-14 at 3 57 06 PM" src="https://media.github.ibm.com/user/265755/files/afb79384-e565-441c-a4c0-87a641cf15d0">

- After you configure your registrar or DNS provider, it can take up to 24 hours for the changes to take effect. When it is verified that the specified name servers were configured correctly for your domain or subdomain, the domain's status changes from ```Pending``` to ```Active```.
