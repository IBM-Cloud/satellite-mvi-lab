# Satellite Deployer

## usage

### prepare
- make sure podman is installed
- build the container:
```
  ./sat-deploy.sh build
```
- copy sample-configurations/sat-ibm-cloud-roks to some folder
```
  mkdir -p data/config
  cp -r ./sample-configurations/sat-ibm-cloud-roks data/config/sample
```


### create artifacts

```
export STATUS_DIR=$(pwd)/data/status/sample
export CONFIG_DIR=$(pwd)/data/config/sample
export IBM_CLOUD_API_KEY=*****

./sat-deploy.sh env apply -e env_id=<some name>
```

### destroy artifacts

```
export STATUS_DIR=$(pwd)/data/status/sample
export CONFIG_DIR=$(pwd)/data/config/sample
export IBM_CLOUD_API_KEY=*****

./sat-deploy.sh env destroy -e env_id=<some name> --confirm-destroy
```