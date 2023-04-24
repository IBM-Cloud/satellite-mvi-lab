# Satellite Deployer

## prereqs
- podman installed
- on MacOS make sure to have mounted home folders, i.e.
```bash
podman machine init --cpus=4 --memory=4096 -v $HOME:$HOME
```
- publicly accessable qcow image to RHCOS. e.g. cos://eu-de/images-mvi-on-sat/rhcos-4.10.37-x86_64-ibmcloud.x86_64.qcow2
- resource group should exist

- [prepare ibm cloud account](prerequisites.md)

## prepare
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

## create satellite + OpenShift cluster

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

## configure OpenShift Data Foundation(ODF)

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
# find you sat location id
export SAT_LOCATION_ID=$(ibmcloud sat location ls --output json | jq -r --arg satloc "${ENV_ID}-sat" '.[]  | select(.name == $satloc) | .id')
# echo sat location id 
echo $SAT_LOCATION_ID
# create storage template
ibmcloud sat storage config create --name "odf-local-${ENV_ID}" --template-name odf-local --template-version 4.10 \
--location "${SAT_LOCATION_ID}" -p "auto-discover-devices=false" -p "iam-api-key=${IBM_ODF_API_KEY}" \
 -p "osd-device-path=/dev/vde" -p "ignore-noobaa=true"
# get cluster id
export $SAT_ROKS_CLUSTER_ID=$(ibmcloud oc cluster get -c "${ENV_ID}-sat-roks" --output json | jq -r .id)
echo $SAT_ROKS_CLUSTER_ID
# create storage assignment
ibmcloud sat storage assignment create --name "${ENV_ID}-assignment" -c "${SAT_ROKS_CLUSTER_ID}" --config "odf-local-${ENV_ID}"
```
Wait 5-10 minutes and watch the output of until it is ready
```bash
oc get ocscluster -o json | jq .items[].status
```

{
  "storageClusterStatus": "Ready"
}

## activate OpenShift registry
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

## install Maximo core

## add a GPU node to the environment

## install MVI

## expose MAS to the internet

## load demo model and conect MVI mobile

## destroy artifacts

```
export STATUS_DIR=$(pwd)/data/status/sample
export CONFIG_DIR=$(pwd)/data/config/sample
export IBM_CLOUD_API_KEY=*****

./sat-deploy.sh env destroy -e env_id=<some name> --confirm-destroy
```