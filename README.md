# Satellite Deployer

## usage

#### prereqs
- podman installed
- on MacOS make sure to have mounted home folders, i.e.
```
podman machine init --cpus=4 --memory=4096 -v $HOME:$HOME
```


### prepare
- make sure podman is installed
- build the container:
```
  ./sat-deploy.sh build
```
- copy sample-configurations/sat-ibm-cloud-roks to some folder
```
  mkdir -p data/config/sample
  mkdir -p data/status/sample
  cp -r ./sample-configurations/sat-ibm-cloud-roks/* data/config/sample
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