# MVI on Satellite Deployer

This project is based on IBM Cloud Pak Deployer https://github.com/IBM/cloud-pak-deployer  
It was stripped down before satellite specific components weere added (still holds many unused artifacts). If time permits we intend to submit satellite components upstream. Credits to the developers of Cloud Pak Deployer.

The following steps will install Maximo Visual Inspection on an OpenShift cluster managed by IBM Cloud Satellite. For the purpose of this lab, the satellite location is hosted on IBM Cloud VPC.

At the time of writing this MVI 8.8, which comes with Maximo Application Suite 8.10, supports only OpenShift 4.10. As a result this only has been tested on OpenShift 4.10 so far.

<p align="center"><img src="images/deployment.png" width="400" style="background-color: white"/></p>

## 1. Prerequisites
- Podman installed
- On MacOS make sure to have mounted home folders, i.e.
```bash
podman machine init --cpus=4 --memory=4096 -v $HOME:$HOME
```
- Publicly accessable qcow image to RHCOS. e.g. cos://eu-de/images-mvi-on-sat/rhcos-4.10.37-x86_64-ibmcloud.x86_64.qcow2
- Resource group should exist
- [Prepare ibm cloud account](prerequisites.md)

## 2. Prepare
> Estimated time: 5 minutes
- Make sure podman is installed
- Build the container:
```bash
./sat-deploy.sh build
```
- Copy sample-configurations/sat-ibm-cloud-roks to some folder
```bash
mkdir -p data/config/sample
mkdir -p data/status/sample
cp -r ./sample-configurations/sat-ibm-cloud-roks/* data/config/sample
```
- Update ```resource_group``` in ```data/config/sample/config/sat-ibm-cloud-roks.yaml```
- Update href for ```custom_image``` in ```data/config/sample/config/sat-ibm-cloud-roks.yaml```
- Update ```ibm_cloud_region``` in ```data/config/sample/inventory/sample.inv```
- Update ```ibm_cloud_location``` (for satellite) in ```data/config/sample/inventory/sample.inv```

## 3. Create Satellite Location + OpenShift cluster
> Estimated time (steps 3,4,5 combined): 1.5 hours 
```bash
export STATUS_DIR=$(pwd)/data/status/sample
export CONFIG_DIR=$(pwd)/data/config/sample
export IBM_CLOUD_API_KEY=*****
export IBM_ODF_API_KEY=*****
export ENV_ID=xy-mvi5  # replace with the name of your environment
export OCP_PULL_SECRET=''  # If you have a pull secret for OCP, set this variable. Keep the single quotes around the pull secret

./sat-deploy.sh env apply -e env_id="${ENV_ID}" -e IBM_ODF_API_KEY="${IBM_ODF_API_KEY}" -e OCP_PULL_SECRET='${OCP_PULL_SECRET}' -v
```

If you want to open the OpenShift console at this stage, connect to the private network of your Satellite Location using the wireguard configuration file found in:
```code
data/status/sample/downloads/client.conf
```

It will take a while till you can view the resources created and in normal state. You can track the status of the resources created by reviewing the logs 

Confirm the Satellite Location is created successfully
```
ibmcloud sat location get --location ${ENV_ID}-sat
```

Confirm the OpenShift cluster is created successfully
```
ibmcloud sat cluster get --cluster ${ENV_ID}-sat-roks
```
## 4. Configure OpenShift Data Foundation(ODF)

This step is done by the automation. For background information visit [ui-docs/odf.md](./ui-docs/odf.md)
- You can confirm the that the storage assignment is successful by running the following command
```
ibmcloud sat storage config get --config ${ENV_ID}-odf-local
```
## 5. Activate OpenShift registry

This step is done by the automation. For background information visit [ui-docs/registry.md](./ui-docs/registry.md)
- Confirm the image registry is created successfully
```
oc get pvc openshift-image-registry -n openshift-image-registry
NAME                       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          AGE
openshift-image-registry   Bound    pvc-3c333a3b-472f-4fd0-95fa-74f252a3aece   100Gi      RWX            sat-ocs-cephfs-gold   19h
```
## 6. Add a GPU node to the environment
> Estimated time: 10 minutes

Edit configuration file ```data/config/sample/config/sat-ibm-cloud-roks.yaml``` and uncomment gpu node in section ```sat_host```.<br>
Stay in the same shell as before, then requirement variables are still set. Execute the following apply command.
```bash
./sat-deploy.sh env apply -e env_id="${ENV_ID}" -v --confirm-destroy
```
> Note: Due to limited capacity of GPU instances this command may fail. If it fails, try a different zone. Check if a failed GPU vsi is created and make sure to delete it before executing the command again.

### Deploy the Nvidia GPU operator
> Estimated time: 15 minutes

Start a shell in the deployment container:
```bash
./sat-deploy.sh env cmd -e ENV_ID="${ENV_ID}"
```
You should have an command prompt inside the docker container, which contains all CLIs like ibmcloud and oc.
Connect to your Cloud Account and Openshift cluster:
```bash
ibmcloud login --apikey $IBM_CLOUD_API_KEY --no-region
ibmcloud oc cluster config --admin -c "${ENV_ID}-sat-roks"
```
```bash
ROLE_NAME=nvidia_gpu ansible-playbook ibm.mas_devops.run_role
```
Normally this step would fail with Satellite ROKS clusters because of the following issue https://github.com/NVIDIA/gpu-operator/issues/428. We addressed this automatically in previous steps of the automation, which sets the right imagetag for the NVIDIA operator.
<br>

Confirm that the ClusterPolicy is successfully created and is in ready state:
```
oc get clusterpolicy -n nvidia-gpu-operator

NAME                 STATUS   AGE
gpu-cluster-policy   ready    2023-06-05T18:52:38Z
```

To learn more about this step and troubleshooting, visit [ui-docs/gpu.md](./ui-docs/gpu.md)

## 7. Install Maximo core
> Estimate time: 1 hour
- Copy Maximo configuration files:

```bash
mkdir -p data/status/sample/mvi
cp -r ./sample-configurations/mvi/* data/status/sample/mvi

```
- Edit and complete ```data/status/sample/mvi/masEnv.sh```
Look for all parametes in brackets \<param>

- Run the automation playbook. cmd container should be still running. If not start again and login to OpenShift.

```bash
source /data/status/mvi/masEnv.sh
ansible-playbook ibm.mas_devops.oneclick_core

```

- Take a note of the superuser name and password displayed at the end of the playbook.

<br>The superuser credentials are saved in ```${MAS_INSTANCE_ID}-credentials-superuser``` secret. You can get the route for the admin dashboard anytime using the following command.
```
oc get route ${MAS_INSTANCE_ID}-admin in mas-${ENV_ID}-core
```

For more information on this step, visit [ui-docs/mas.md](./ui-docs/mas.md)

## 8. Install MVI
> Estimated time: 30 minutes

```bash
source /data/status/mvi/masEnv.sh
ansible-playbook ibm.mas_devops.oneclick_add_visualinspection

```

Currently MVI does not support ODF but a fix is on the way. In the meantime we use this workaround:

```bash
oc patch scc ibm-mas-visualinspection-scc \
    --type='json' \
    --patch='[
        {"op": "replace", "path": "/seLinuxContext/type", "value": "MustRunAs"}
    ]'
```

Trigger recreation of MVI pods

```bash
oc delete pod -n mas-${MAS_INSTANCE_ID}-visualinspection --all
```

Wait until all pods have been recreated. The pvc task pod is expected to fail after the patch. The job did complete before the patch.

```bash
oc get pod -n mas-${MAS_INSTANCE_ID}-visualinspection
```
<br>

For more information on this step, visit [ui-docs/mvi.md](./ui-docs/mvi.md)

## 9. Login as superuser and create admin user
>Estimated time: 3 minutes

- Using the superuser credentials that were created upon successful installation to login to MAS UI ```https://admin.<maximo-domain>```
![](images/mas-login.png)
- Go to ```Administration``` > ```Users``` to create a new admin user (15 AppPoints) and fill in the details for the user like name, email and password.

- Create admin user
![](images/admin-identity.png)
- Assign application and administration ```entitlements``` -> ```Premium```
![](images/admin-entitlement.png)
- Save the credentials, logout of the super user and login with the new admin user created to confirm access to the platform.

## 10. Expose MAS to the internet
> Estimated time: 20 minutes

- Edit configuration file ```data/config/sample/config/sat-ibm-cloud-roks.yaml``` and uncomment the loadbalancer.
- Run the following command:

```bash
./sat-deploy.sh env apply -e env_id="${ENV_ID}" -v
```

## 11. Load demo model and conect MVI mobile



## 12. Destroy artifacts

If the command fails due to some reason (timeout), start it again.

```bash
./sat-deploy.sh env destroy -e env_id="${ENV_ID}" --confirm-destroy
```
