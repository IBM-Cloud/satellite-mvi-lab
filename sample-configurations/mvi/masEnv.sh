export IBM_ENTITLEMENT_KEY=<insert key> #Lookup your entitlement key from the IBM Container Library
export MAS_INSTANCE_ID=inst1 #Declare the instance ID for the MAS install
export MAS_CONFIG_DIR=/data/status/mvi #Directory where generated config files will be saved (you may also provide pre-generated config files here)
export SLS_LICENSE_ID=<insert license id> #The license ID must match the license file available in SLS_LICENSE_FILE
export SLS_LICENSE_FILE=/data/status/mvi/license.dat #The path to the location of the license file.
export UDS_CONTACT_EMAIL=<email> #Defines the email for person to contact for UDS
export UDS_CONTACT_FIRSTNAME=<first name> #Defines the first name of the person to contact for UDS
export UDS_CONTACT_LASTNAME=<last name> #Defines the last name of the person to contact for UDS
export CLUSTER_MONITORING_ACTION=none #bug in OCP < 4.11 https://bugzilla.redhat.com/show_bug.cgi?id=2089224

export PROMETHEUS_ALERTMGR_STORAGE_CLASS=sat-ocs-cephrbd-gold
export PROMETHEUS_STORAGE_CLASS=sat-ocs-cephfs-gold
export PROMETHEUS_USERWORKLOAD_STORAGE_CLASS=sat-ocs-cephfs-gold
export GRAFANA_INSTANCE_STORAGE_CLASS=sat-ocs-cephfs-gold
export MONGODB_STORAGE_CLASS=sat-ocs-cephfs-gold
export UDS_STORAGE_CLASS=sat-ocs-cephfs-gold
export MAS_APP_SETTINGS_VISUALINSPECTION_STORAGE_CLASS=sat-ocs-cephfs-gold

export MONGODB_CPU_REQUESTS=200m
export MONGODB_REPLICAS=1

export DNS_PROVIDER=cis
export MAS_DOMAIN=<your custom domain>
export MAS_CLUSTER_ISSUER=inst1-cis-le-prod
export CIS_SUBDOMAIN=maximo    # maximo domain will be maximo.<your custom domain>
export CIS_EMAIL=<your email>
export CIS_APIKEY=<CIS api key>
export CIS_CRN='<your cis crn>'  #keep the single quotes
