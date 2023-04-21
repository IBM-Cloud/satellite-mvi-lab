#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

echo "-------------------------------------------------------------------------------"
echo "Entering Cloud Pak Deployer command line in a container."
echo 'Use the "exit" command to leave the container and return to the hosting server.'
echo "-------------------------------------------------------------------------------"

export PS1='\[\e]0;\w\a\]\n[\#] \[\e[32m\u@Satellite Deployer:\[\e[33m\]\w \e[m\$ ';

oc_zip=$(find $STATUS_DIR/downloads/ -name "openshift-client*" | tail -1)
if [ "$oc_zip" != "" ];then
  echo "Installing OpenShift client"
  tar xvzf $oc_zip -C /usr/local/bin --exclude='README.md' > /dev/null
  if [ -e $STATUS_DIR/openshift/kubeconfig ];then
    # Use a copy of the kubeconfig file so that the command line doesn't conflict with an active deployer
    cp -f $STATUS_DIR/openshift/kubeconfig /tmp/kubeconfig
    export KUBECONFIG=/tmp/kubeconfig
    # Show the current context
    oc_context=$(oc config current-context)
    echo "Current OpenShift context: $oc_context"
  else
    echo "No existing OpenShift configuration found, you will need to login to OpenShift first."
  fi
else
  echo "Warning: OpenShift client not found under $STATUS_DIR/downloads, oc command will not be available."
fi

ibm_cloud=$(find $STATUS_DIR/downloads/ -name "ibmcloud-linux*" | tail -1)
if [ "$ibm_cloud" != "" ];then
  echo "Installing ibmcloud cli"
  $ibm_cloud
  ibmcloud plugin install kubernetes-service -f
  ibmcloud plugin install container-registry -f
  ibmcloud plugin install is -f
else
  echo "Warning: ibmcloud cli not found under $STATUS_DIR/downloads, ibmcloud command will not be available."
fi

/bin/bash

exit 0