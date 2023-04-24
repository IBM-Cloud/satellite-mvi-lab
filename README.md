# MVI on Satellite Deployer

## Prereqs
- podman installed
- on MacOS make sure to have mounted home folders, i.e.
```bash
podman machine init --cpus=4 --memory=4096 -v $HOME:$HOME
```
- publicly accessable qcow image to RHCOS. e.g. cos://eu-de/images-mvi-on-sat/rhcos-4.10.37-x86_64-ibmcloud.x86_64.qcow2
- resource group should exist

- [prepare ibm cloud account](prerequisites.md)

## Prepare
- make sure podman is installed
- build the container:
```bash
  ./sat-deploy.sh build
```
- copy sample-configurations/sat-ibm-cloud-roks to some folder
```bash
  mkdir -p data/config/sample
  mkdir -p data/status/sample
  cp -r ./sample-configurations/sat-ibm-cloud-roks/* data/config/sample
```
- update resource_group in data/config/sample/config/sat-ibm-cloud-roks.yaml
- update href for custom_image in data/config/sample/config/sat-ibm-cloud-roks.yaml

## Create satellite + OpenShift cluster

```bash
export STATUS_DIR=$(pwd)/data/status/sample
export CONFIG_DIR=$(pwd)/data/config/sample
export IBM_CLOUD_API_KEY=*****
export IBM_ODF_API_KEY=*****
export ENV_ID=xy-mvi5

./sat-deploy.sh env apply -e env_id="${ENV_ID}" -v
```

Connect to the private network of your Satellite Location using the wireguard configuration file found in:
```code
data/status/sample/downloads/client.conf
```

Wait until OpenShift has become ready. Currently Ansible exits before this.

## Configure OpenShift Data Foundation(ODF)

### TODO: write an Ansible playbook for this task

Start a shell in the deployment container:
```bash
./sat-deploy.sh env cmd -e ENV_ID="${ENV_ID}" -e IBM_ODF_API_KEY="${IBM_ODF_API_KEY}"
```
You should have an command prompt inside the docker container, which contains all CLIs like ibmcloud and oc.
Connect to your Cloud Account and Openshift cluster:
```bash
ibmcloud login --apikey $IBM_CLOUD_API_KEY
ibmcloud target -g <YOUR_RESOURCE_GROUP> -r <YOUR_REGION>
ibmcloud oc clusters
ibmcloud oc cluster config --admin -c "${ENV_ID}-sat-roks"
```
Check that you could run command against your cluster using the oc command.
```bash
oc get projects
oc get nodes
```
The following commands will create a satellite storage template and assign it to our cluster. Please use the IBM Cloud API key from the prerequistes designated for the Open Shift Data Foundation deployment. We deploy ODF on all nodes which have a disk id of /dev/vde.
```bash
export SAT_LOCATION_ID=$(ibmcloud sat location ls --output json | jq -r --arg satloc "${ENV_ID}-sat" '.[]  | select(.name == $satloc) | .id')
echo $SAT_LOCATION_ID
ibmcloud sat storage config create --name "odf-local-${ENV_ID}" --template-name odf-local --template-version 4.10 \
--location "${SAT_LOCATION_ID}" -p "auto-discover-devices=false" -p "iam-api-key=${IBM_ODF_API_KEY}" \
 -p "osd-device-path=/dev/vde" -p "ignore-noobaa=true"
export SAT_ROKS_CLUSTER_ID=$(ibmcloud oc cluster get -c "${ENV_ID}-sat-roks" --output json | jq -r .id)
echo $SAT_ROKS_CLUSTER_ID
ibmcloud sat storage assignment create --name "${ENV_ID}-assignment" -c "${SAT_ROKS_CLUSTER_ID}" --config "odf-local-${ENV_ID}"

```
Wait 5-10 minutes and watch the output of until it is ready. Check the OpenShift UI for what is going on: operators, pods, etc.
```bash
oc get ocscluster -o json | jq .items[].status
```

Wait for status gats into ready state. Ignore intermediate errors of this state.
{
  "storageClusterStatus": "Ready"
}

## Activate OpenShift registry
Run the following commmand to create a PVC in OpenShift for the OpenShift Registray and activate the Registry Operator
```bash
oc create -f - <<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: openshift-image-registry
  namespace: openshift-image-registry
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: sat-ocs-cephfs-gold
EOF

oc patch configs.imageregistry.operator.openshift.io/cluster \
    --type='json' \
    --patch='[
        {"op": "replace", "path": "/spec/managementState", "value": "Managed"},
        {"op": "replace", "path": "/spec/storage", "value": {"pvc":{"claim": "openshift-image-registry" }}}
    ]'

```
Exit container.

## Add a GPU node to the environment

Edit configuration file data/config/sample/config/sat-ibm-cloud-roks.yaml and uncomment gpu node in section sat_host.
Stay in the same shell as before, then requirement variables are still set. Execute the following apply command. Note
that due to limited capacity of GPU instances this command may fail. If it fails, try a different zone.

```bash
./sat-deploy.sh env apply -e env_id="${ENV_ID}" -v --confirm-destroy
```

### Deploy the Nvidia pgu operator

Start a shell in the deployment container:
```bash
./sat-deploy.sh env cmd -e ENV_ID="${ENV_ID}"
```
You should have an command prompt inside the docker container, which contains all CLIs like ibmcloud and oc.
Connect to your Cloud Account and Openshift cluster:
```bash
ibmcloud login --apikey $IBM_CLOUD_API_KEY
ibmcloud target -g <YOUR_RESOURCE_GROUP> -r <YOUR_REGION>
ibmcloud oc clusters
ibmcloud oc cluster config --admin -c "${ENV_ID}-sat-roks"

```

```bash
ROLE_NAME=nvidia_gpu ansible-playbook ibm.mas_devops.run_role
```

Note: Due to a bug the last task won't succeed:  "Wait for Cluster Policy instance to be ready"
You can terminate it by pressing \<ctrl>\<c>

### Fix failing install og gpu operator
Due to this bug the gpu operator fails to install: https://github.com/NVIDIA/gpu-operator/issues/428

To fix this we need to create a new tag using this template:

```
oc -n openshift tag <copy from release.txt> driver-toolkit:<get from pod name>
```

In the OpenShift console go to workloads -> pods and filter namespace nvidia-gpu-operator. Look for pod named
nvidia-driver-daemonset-xxx-. Example:
nvidia-driver-daemonset-410.84.202303181059-0-mcg6m
We need the middle part, in this example: 410.84.202303181059-0, so the tag to be created will be
driver-toolkit:410.84.202303181059-0

The image name and hash can be found in realease.txt of OCP clients:
https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.10.55/release.txt

Check that machine os version (approximately line 20) matches our tag. If this is not the case, go to an earlier
or later version, i.e. https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.10.56/release.txt
Find image for driver-toolkit, i.e. 
quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:51e2043014581f30f456f54aacd983b6736b3a7d83c171ed7e0f78d3c13b550e

- Complete the command, i.e.
```
oc -n openshift tag quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:51e2043014581f30f456f54aacd983b6736b3a7d83c171ed7e0f78d3c13b550e driver-toolkit:410.84.202303181059-0
```
- Exeute the command. Then delete the pod nvidia-driver-daemonset-xxx-. It will get recreated and the driver will install.

## Install Maximo core

- Copy Maximo configuration files:

```bash
  mkdir -p data/status/sample/mvi
  cp -r ./sample-configurations/mvi/* data/status/sample/mvi

```
- Edit and complete data/status/sample/mvi/masEnv.sh 
Look for all parametes in brackets \<param>

- Run the automation playbook. cmd container should be still running. If not start again and login to OpenShift.

```bash
source /data/status/mvi/masEnv.sh
ansible-playbook ibm.mas_devops.oneclick_core

```

- Take a note of the superuser name and password displayed at the end of the playbook.

## Install MVI

```bash
source /data/status/mvi/masEnv.sh
ansible-playbook ibm.mas_devops.oneclick_add_visualinspection

```

Currently MVI does not support ODF but a fix is on the way. In the meantime we use this workaround:

```bash
oc edit scc ibm-mas-visualinspection-scc
```

Look for seLinuxContext and change type from "RunAsAny" to "MustRunAs"
Trigger recreation of MVI pods

```bash
oc project mas-inst1-visualinspection
oc delete pod --all

```

## Login as superuser and create admin user

- Login to the UI as superuser
- Create admin user
- Assign application and administration entitlements -> Premium
- Verify that MVI access is to to Administrator

## Expose MAS to the internet

- Edit configuration file data/config/sample/config/sat-ibm-cloud-roks.yaml and uncomment the loadbalancer.
- Run the following command:

```bash
./sat-deploy.sh env apply -e env_id="${ENV_ID}" -v
```

### TODO move to Ansible role
Start a shell in the deployment container:
```bash
./sat-deploy.sh env cmd -e ENV_ID="${ENV_ID}"
```
You should have an command prompt inside the docker container, which contains all CLIs like ibmcloud and oc.
Connect to your Cloud Account and Openshift cluster:
```bash
ibmcloud login --apikey $IBM_CLOUD_API_KEY
ibmcloud target -g <YOUR_RESOURCE_GROUP> -r <YOUR_REGION>
```

Remove all IPs from the subdomain.
Take a note of the IP addresses
```bash
ibmcloud oc nlb-dns ls -c $ENV_ID-sat-roks
```

Remove IP one by one
```bash
ibmcloud oc nlb-dns rm vpc-gen2 -c $ENV_ID-sat-roks --nlb-subdomain $MVI_SUBDOMAIN --ip <ip address>
```

Add IP address of loadbalancer
```bash
export MVI_SUBDOMAIN=$(ibmcloud oc nlb-dns ls -c $ENV_ID-sat-roks --output json -q | jq -r '.[] | .nlbHost')
echo $MVI_SUBDOMAIN
export PUBLIC_IP=$(ibmcloud is lb rh-mvi5-nlb --output json -q | jq '.public_ips[] | .address' | tr -d '"')
echo $PUBLIC_IP
ibmcloud oc nlb-dns add -c $ENV_ID-sat-roks --ip $PUBLIC_IP --nlb-host $MVI_SUBDOMAIN -q

```

## Load demo model and conect MVI mobile

## Destroy artifacts

Start a shell in the deployment container:
```bash
./sat-deploy.sh env cmd -e ENV_ID="${ENV_ID}"
```

Remove the leftover Satellite storage association for ODF.
```bash
export SAT_ASSIGN_UUID=$(ibmcloud sat storage assignment ls --output json | jq -r --arg assoc "${ENV_ID}-assignment" '.[]  | select(.name == $assoc) | .uuid')
ibmcloud sat storage assignment rm -f --assignment $SAT_ASSIGN_UUID
```

Remove the leftover Satellite storage template for ODF.
```bash
export SAT_STORAGE_UUID=$(ibmcloud sat storage config ls --output json | jq -r --arg config "odf-local-${ENV_ID}" | jq -r --arg config "odf-local-${ENV_ID}" '.[]  | select(."config-name" == $config) | .uuid')
ibmcloud sat storage config rm -f --config $SAT_STORAGE_UUID
```

Exit container and run the following command to cleanup:

```bash
./sat-deploy.sh env destroy -e env_id="${ENV_ID}" --confirm-destroy
```