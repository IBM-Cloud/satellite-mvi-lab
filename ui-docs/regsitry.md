# Activate OpenShift registry
This document shows the steps to set up the OpenShift internal registry. **This step is already done as part of the automation in step 5.**

- Run the following commmand to create a PVC in OpenShift for the OpenShift Registry and activate the Registry Operator
``` bash
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
- Exit container.

## Resources
- <a href="https://www.ibm.com/docs/en/mas-cd/continuous-delivery?topic=requirements-enabling-openshift-internal-image-registry">Enabling the OpenShift internal image registry</a>
