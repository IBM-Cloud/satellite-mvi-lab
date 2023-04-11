#! /bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

# --------------------------------------------------------------------------------------------------------- #
# Functions                                                                                                 #
# --------------------------------------------------------------------------------------------------------- #
command_usage() {
  echo
  echo "Usage: $0 SUBCOMMAND [ACTION] [OPTIONS]"
  echo
  echo "SUBCOMMAND:"
  echo "  environment,env           Apply configuration to create, modify or destroy an environment"
  echo "  vault                     Get, create, modify or delete secrets in the configured vault"
  echo "  build                     Build the container image for the Satellite Deployer"
  echo "  help,h                    Show help"
  echo
  echo "ACTION:"
  echo "  environment:"
  echo "    apply                   Create a new or modify an existing environment"
  echo "    destroy                 Destroy an existing environment"
  echo "    logs                    Show (tail) the logs of the apply/destroy process"
  echo "    command,cmd             Opens a shell environment to run commands such as the OpenShift client (oc)"
  echo "    kill                    Kill the current apply/destroy process"
  echo "  vault:"
  echo "    get                     Get a secret from the vault and return its value"
  echo "    set                     Create or update a secret in the vault"
  echo "    delete                  Delete a secret from the vault"
  echo "    list                    List secrets for the specified vault group"
  echo "  build:                    No actions."
  echo
  echo "OPTIONS:"
  echo "Generic options (environment variable). You can specify the options on the command line or set an environment variable before running the $0 command:"
  echo "  --status-dir,-l <dir>         Local directory to store logs and other provisioning files (\$STATUS_DIR)"
  echo "  --config-dir,-c <dir>         Directory to read the configuration from. Must be specified. (\$CONFIG_DIR)"
  echo "  --ibm-cloud-api-key <apikey>  API key to authenticate to the IBM Cloud (\$IBM_CLOUD_API_KEY)"
  echo "  --vault-password              Password or token to login to the vault (\$VAULT_PASSWORD)"
  echo "  --vault-cert-ca-file          File with CA of login certificate (\$VAULT_CERT_CA_FILE)"
  echo "  --vault-cert-key-file         File with login certificate key (\$VAULT_CERT_KEYFILE)"
  echo "  --vault-cert-cert-file        File with login certificate (\$VAULT_CERT_CERT_FILE)"
  echo "  --extra-vars,-e <key=value>   Extra environment variable for the deployer. You can specify multiple --extra-vars"
  echo "  --check-only                  Skip all provisioning and deployment tasks. Only run the validation and generation."
  echo "  -v                            Show standard ansible output (\$ANSIBLE_STANDARD_OUTPUT)"
  echo "  -vv, -vvv, -vvvv, ...         Show verbose ansible output, verbose option used is (number of v)-1 (\$ANSIBLE_VERBOSE)"
  echo
  echo "Satellite Deployer development options:"
  echo "  --sat-develop                 Map current directory to automation scripts, only for development/debug (\$SAT_DEVELOP)"
  echo 
  echo "Options for environment subcommand:"
  echo "  --confirm-destroy             Confirm that infra may be destroyed. Required for action destroy and when apply destroys infrastructure (\$CONFIRM_DESTROY)"
  echo
  echo "Options for vault subcommand:"
  echo "  --vault-group,-vg <name>          Group of secret (\$VAULT_GROUP)"
  echo "  --vault-secret,-vs <name>         Secret name to get, set or delete (\$VAULT_SECRET)"
  echo "  --vault-secret-value,-vsv <value> Secret value to set (\$VAULT_SECRET_VALUE)"
  echo "  --vault-secret-file,-vsf <value>  File with secret value to set or get (\$VAULT_SECRET_FILE)"
  echo
  exit $1
}

# Show the logs of the currently running env process
run_env_logs() {
  if [[ "${ACTIVE_CONTAINER_ID}" != "" ]];then
    ${CONTAINER_ENGINE} logs -f ${ACTIVE_CONTAINER_ID}
  else
    ${CONTAINER_ENGINE} logs ${CURRENT_CONTAINER_ID}
  fi
}

# Find the name of the latest ibm-cp-datacore archive file in the downloads directory
get_cp_datacore_archive() {
  CP_DATACORE_ARCHIVE=$(find $STATUS_DIR/downloads -regex '.*ibm-cp-datacore-[0-9]+[.][0-9]+[.][0-9]+.*.tgz' | tail -n 1)
  if [ "$CP_DATACORE_ARCHIVE" == "" ];then
    echo "Could not find ibm-cp-datacore archive in $STATUS_DIR/downloads directory. This file is needed for the portable registry."
    exit 1
  fi
}

# --------------------------------------------------------------------------------------------------------- #
# Initialize                                                                                                #
# --------------------------------------------------------------------------------------------------------- #
if [ "${ANSIBLE_STANDARD_OUTPUT}" == "" ];then ANSIBLE_STANDARD_OUTPUT=false;fi
if [ "${CONFIRM_DESTROY}" == "" ];then CONFIRM_DESTROY=false;fi
if [ "${CHECK_ONLY}" == "" ];then CHECK_ONLY=false;fi
if [ "${SAT_DEVELOP}" == "" ];then SAT_DEVELOP=false;fi

# Check if the command is running inside a container. This means that the command should not start docker or podman
# but run the Ansible automation directly.
if [ -f /run/.containerenv ] || [ -f /.dockerenv ];then
  INSIDE_CONTAINER=true
else
  INSIDE_CONTAINER=false
fi

arrExtraKey=()
arrExtraValue=()

# --------------------------------------------------------------------------------------------------------- #
# Check subcommand and action                                                                               #
# --------------------------------------------------------------------------------------------------------- #

# Check number of parameters
if [ "$#" -lt 1 ]; then
  command_usage
fi

# Check that subcommand is valid
export SUBCOMMAND=$(echo "$1" | tr '[:upper:]' '[:lower:]' )
case "$SUBCOMMAND" in
env|environment)
  export SUBCOMMAND="environment"
  shift 1
  ;;
vault)
  shift 1
  ;;
build)
  if ${INSIDE_CONTAINER};then
    echo "build subcommand not allowed when running inside container"
    exit 99
  fi
  shift 1
  ;;
h|help)
  command_usage 0
  ;;
*) 
  echo "Invalid subcommand."
  command_usage 1
  ;;
esac

# Check that action is valid for subcommand
export ACTION=$(echo "$1" | tr '[:upper:]' '[:lower:]' )
case "$SUBCOMMAND" in
environment)
  case "$ACTION" in
  --help|-h)
    command_usage 0
    ;;
  apply|destroy)
    shift 1
    ;;
  logs|kill|download|save)
    if ${INSIDE_CONTAINER};then
      echo "$ACTION action not allowed when running inside container"
      exit 99
    fi
    shift 1
    ;;
  command|cmd)
    if ${INSIDE_CONTAINER};then
      echo "$ACTION action not allowed when running inside container"
      exit 99
    fi
    export ACTION="command"
    shift 1
    ;;
  *)
    echo "Invalid action for environment subcommand."
    command_usage 1
    ;;
  esac
  ;;
vault)
  case "$ACTION" in
  --help|-h)
    command_usage 0
    ;;
  get|set|delete|list)
    shift 1
    ;;
  *)
    echo "Invalid action for vault subcommand."
    command_usage 1
    ;;
  esac
  ;;
build)
  ;;
esac

# --------------------------------------------------------------------------------------------------------- #
# Parse remainder of the parameters and populate environment variables                                      #
# --------------------------------------------------------------------------------------------------------- #

# Parse parameters
PARAMS=""
while (( "$#" )); do
  case "$1" in
  --help|-h)
    command_usage 0
    ;;
  --config-dir*|-c*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export CONFIG_DIR="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export CONFIG_DIR=$2
      shift 2
    else
      echo "Error: Missing configuration directory for --config-dir parameter."
      command_usage 2
    fi
    fi
    ;;
  --status-dir*|-l*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export STATUS_DIR="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export STATUS_DIR=$2
      shift 2
    else
      echo "Error: Missing argument for --status-dir parameter."
      command_usage 2
    fi
    fi
    ;;
  --ibm-cloud-api-key*|-k*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export IBM_CLOUD_API_KEY="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export IBM_CLOUD_API_KEY=$2
      shift 2
    else
      echo "Error: Missing argument for --ibm-cloud-api-key parameter."
      command_usage 2
    fi
    fi
    ;;
  --extra-vars*|-e*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      CURRENT_EXTRA_VAR="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      CURRENT_EXTRA_VAR=$2
      shift 2
    else
      echo "Error: Missing argument for --extra-vars parameter."
      command_usage 2
    fi
    fi
    # Check if the environment variable has the format of key=value
    extra_key=$(echo ${CURRENT_EXTRA_VAR} | cut -s -d= -f1)
    extra_value=$(echo ${CURRENT_EXTRA_VAR} | cut -s -d= -f2)
    if [[ "${extra_key}" == "" || "${extra_value}" == "" ]];then
      echo "Error: --extra-vars must be specified as <key>=<value>."
      command_usage 2
    fi
    arrExtraKey+=("${extra_key}")
    arrExtraValue+=("${extra_value}")
    ;;
  --vault-secret-file*|-vsf*)
    if [[ "${SUBCOMMAND}" != "vault" ]];then
      echo "Error: --vault-secret-file is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    if [ ! -z "${VAULT_SECRET_VALUE}" ];then
      echo "Error: either specify --vault-secret-file or --vault-secret-value, not both."
      command_usage 2
    fi
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_SECRET_FILE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_SECRET_FILE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-secret-file parameter."
      command_usage 2
    fi
    fi
    if [ ! -z ${VAULT_SECRET_FILE} ] && [[ "${ACTION}" == "set" ]] && [ ! -f ${VAULT_SECRET_FILE} ];then
      echo "Error: Vault secret file ${VAULT_SECRET_FILE} must exist for vault set action."
      command_usage 2
    fi
    if [ ! -z ${VAULT_SECRET_FILE} ] && [[ "${ACTION}" == "get" ]] && [ ! -f ${VAULT_SECRET_FILE} ];then
      touch ${VAULT_SECRET_FILE}
    fi        
    ;;
  --vault-secret-value*|-vsv*)
    if [[ "${SUBCOMMAND}" != "vault" ]];then
      echo "Error: --vault-secret-value is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    if [[ "${ACTION}" != "set" ]];then
      echo "Error: --vault-secret-value is not valid for action $ACTION."
      command_usage 2
    fi
    if [ ! -z "${VAULT_SECRET_FILE}" ];then
      echo "Error: either specify --vault-secret-file or --vault-secret-value, not both."
      command_usage 2
    fi
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_SECRET_VALUE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_SECRET_VALUE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-secret-value parameter."
      command_usage 2
    fi
    fi
    ;;
  # The --vault-secret must be parsed after --vault-secret-value, otherwise the secret value is already
  # picked up when the first part of the option has a match
  --vault-secret*|-vs*)
    if [[ "${SUBCOMMAND}" != "vault" ]];then
      echo "Error: --vault-secret is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_SECRET="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_SECRET=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-secret parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-group*|-vg*)
    if [[ "${SUBCOMMAND}" != "vault" ]];then
      echo "Error: --vault-group is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_GROUP="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_GROUP=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-group parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-password*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_PASSWORD="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_PASSWORD=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-password parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-cert-ca-file*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_CERT_CA_FILE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_CERT_CA_FILE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-cert-ca-file parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-cert-key-file*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_CERT_KEY_FILE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_CERT_KEY_FILE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-cert-key-file parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-cert-cert-file*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_CERT_CERT_FILE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_CERT_CERT_FILE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-cert-cert-file parameter."
      command_usage 2
    fi
    fi
    ;;
  --confirm-destroy)
    if [[ "${SUBCOMMAND}" != "environment" ]];then
      echo "Error: --confirm-destroy is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    export CONFIRM_DESTROY=true
    shift 1
    ;;
  --sat-develop)
    if ${INSIDE_CONTAINER};then
      echo "$1 flag not allowed when running inside container"
      exit 99
    fi
    export SAT_DEVELOP=true
    shift 1
    ;;
  --check-only)
    if [[ "${SUBCOMMAND}" != "environment" ]];then
      echo "Error: --cp-config-only is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    export CHECK_ONLY=true
    shift 1
    ;;  
  -vv*)
    export ANSIBLE_VERBOSE=$(echo -${1:2})
    shift 1
    ;;
  -v)
    export ANSIBLE_STANDARD_OUTPUT=true
    shift 1
    ;;

  -*|--*=)
    echo "Invalid option: $1"
    command_usage 2
    ;;
  *) # preserve remaining arguments
    PARAMS="$PARAMS $1"
    shift
    ;;
  esac
done

# --------------------------------------------------------------------------------------------------------- #
# Check container engine and build if wanted                                                                #
# --------------------------------------------------------------------------------------------------------- #

# container engine used to run the registry, either 'docker' or 'podman'
CONTAINER_ENGINE=

if ! $INSIDE_CONTAINER;then
  # Check if podman or docker command was found
  if command -v podman &> /dev/null;then
    CONTAINER_ENGINE="podman"
  elif command -v docker &> /dev/null;then
    CONTAINER_ENGINE="docker"
  else
    echo "podman or docker command was not found."
    exit 99
  fi

  # If running "build" subcommand, build the image
  if [ "$SUBCOMMAND" == "build" ];then
    echo "Building container image for Satellite Deployer including olm-utils"
    $CONTAINER_ENGINE build -t sat-deployer -f ${SCRIPT_DIR}/Dockerfile.olm-utils ${SCRIPT_DIR}
    exit $?
  fi
fi

# --------------------------------------------------------------------------------------------------------- #
# Check invalid combinations of parameters                                                                  #
# --------------------------------------------------------------------------------------------------------- #

# Validate combination of parameters for subcommand vault
if [[ "${SUBCOMMAND}" == "vault" ]];then
  if [[ "${ACTION}" == "set" && "${VAULT_SECRET_VALUE}" == "" && "${VAULT_SECRET_FILE}" == "" ]] ;then
    echo "--vault-secret-value or --vault-secret-file must be specified for subcommand vault and action set."
    exit 1
  fi
  if [[ "${ACTION}" != "list" && "${VAULT_SECRET}" == "" ]];then
    echo "--vault-secret must be specified for subcommand vault and action ${ACTION}."
    exit 1
  fi
  if [[ "${ACTION}" == "list" && \
        ( "${VAULT_SECRET_VALUE}" != "" || "${VAULT_SECRET_FILE}" != "" ) ]] ;then
    echo "--vault-secret-value and --vault-secret-file not allowed for subcommand vault and action list."
    exit 1
  fi

  if [[ "${ACTION}" != "set" && "${VAULT_SECRET_VALUE}" != "" ]];then
    echo "--vault-secret-value must not be specified for subcommand vault and action ${ACTION}."
    exit 1
  fi
  if [[ "${VAULT_SECRET_VALUE}" != "" && "${VAULT_SECRET_FILE}" != "" ]];then
    echo "Specify either --vault-secret-value or --vault-secret-file, not both."
    exit 1
  fi
fi

# --------------------------------------------------------------------------------------------------------- #
# Check existence of directories                                                                            #
# --------------------------------------------------------------------------------------------------------- #

# Validate if the configuration directory exists and has the correct subdirectories
if [[ "${ACTION}" != "wizard"  && "${ACTION}" != "kill" ]]; then
  if [ "${CONFIG_DIR}" == "" ]; then
    echo "Config directory must be specified using the CONFIG_DIR environment variable or the --config-dir parameter."
    exit 1
  fi
  if [ ! -d "${CONFIG_DIR}" ]; then
    echo "config directory ${CONFIG_DIR} not found."
    exit 1
  fi
  if [ ! -d "${CONFIG_DIR}/config" ]; then
    echo "config directory not found in directory ${CONFIG_DIR}."
    exit 1
  fi
  if [ ! -d "${CONFIG_DIR}/inventory" ]; then
    echo "inventory directory not found in directory ${CONFIG_DIR}."
    exit 1
  fi
fi

# Validate if the status has been set
if [[ "${ACTION}" != "wizard" ]]; then
  if [ "${STATUS_DIR}" == "" ]; then
    echo "Status directory must be specified using the STATUS_DIR environment variable or the --status-dir parameter."
    exit 1
  fi
fi

# --------------------------------------------------------------------------------------------------------- #
# Check existence of certificate files if specified                                                         #
# --------------------------------------------------------------------------------------------------------- #

# Ensure vault certificate files exists
if [[ ! -z $VAULT_CERT_CA_FILE && ! -f $VAULT_CERT_CA_FILE ]];then
    echo "Vault certificate CA file ${VAULT_CERT_CA_FILE} not found."
fi
if [[ ! -z $VAULT_CERT_KEY_FILE && ! -f $VAULT_CERT_KEY_FILE ]];then
    echo "Vault certificate key file ${VAULT_CERT_KEY_FILE} not found."
fi
if [[ ! -z $VAULT_CERT_CERT_FILE && ! -f $VAULT_CERT_CERT_FILE ]];then
    echo "Vault certificate file ${VAULT_CERT_CERT_FILE} not found."
fi

# Set remaining parameters
eval set -- "$PARAMS"

# --------------------------------------------------------------------------------------------------------- #
# Run the Satellite Deployer                                                                                #
# --------------------------------------------------------------------------------------------------------- #

# Show warning if --sat-develop is used
if $SAT_DEVELOP;then
  echo "Warning: SAT_DEVELOP was specified. Current directory $(pwd) will be used for automation script !!!"
  sleep 0.5
fi

# Ensure status directory exists
if [ "$STATUS_DIR" != "" ];then
  mkdir -p $STATUS_DIR/{log,pid}
fi

# Check if the sat-deployer image exists
if ! $INSIDE_CONTAINER;then
  if [[ "$(${CONTAINER_ENGINE} images -q sat-deployer:latest 2> /dev/null)" == "" ]]; then
    echo "Container image sat-deployer does not exist on the local machine, please build first."
    exit 99
  fi
fi

# Check if a container is currently running for this status directory
CURRENT_CONTAINER_ID=""
ACTIVE_CONTAINER_ID=""
if ! $INSIDE_CONTAINER;then
  if [ "${STATUS_DIR}" != "" ];then
    if [ -f ${STATUS_DIR}/pid/container.id ];then
      CURRENT_CONTAINER_ID=$(cat ${STATUS_DIR}/pid/container.id)
      ACTIVE_CONTAINER_ID=${CURRENT_CONTAINER_ID}
      # If container ID was found, check if it is currently running
      if [ "${ACTIVE_CONTAINER_ID}" != "" ];then
        if ! ${CONTAINER_ENGINE} ps --no-trunc | grep -q ${ACTIVE_CONTAINER_ID};then
          ACTIVE_CONTAINER_ID=""
        fi
      fi
    fi
  fi
fi

# If trying to apply or destroy for an active container, just display the logs
if ! $INSIDE_CONTAINER;then
  if [[ "${ACTION}" == "apply" || "${ACTION}" == "destroy" ]];then
    if [[ "${ACTIVE_CONTAINER_ID}" != "" ]];then
      echo "Satellite Deployer is already running for status directory ${STATUS_DIR}"
      echo "Showing the logs of the currently running container ${ACTIVE_CONTAINER_ID}"
      sleep 0.5
      run_env_logs
      exit 0
    fi
  # Display the logs if an active or inactive container was found
  elif [[ "${ACTION}" == "logs" ]];then
    if [[ "${CURRENT_CONTAINER_ID}" == "" ]];then
      echo "Error: No Satellite Deployer process found for the current status directory."
      exit 1
    else
      run_env_logs
      exit 0
    fi
  # Terminate if an active container was found
  elif [[ "${ACTION}" == "kill" ]];then
    if [[ "${ACTIVE_CONTAINER_ID}" == "" ]];then
      echo "Error: No active Satellite Deployer process found for the current status directory."
      exit 1
    else
      echo "Terminating container process ${ACTIVE_CONTAINER_ID}"
      ${CONTAINER_ENGINE} kill ${ACTIVE_CONTAINER_ID}
      exit 0
    fi
  fi
fi

# check selinux
SE_LINUX_OPTION=""
if hash getenforce 2>/dev/null; then
  SELINUXSTATUS=$(getenforce)
  if [ "$SELINUXSTATUS" != "Disabled" ]; then
    SE_LINUX_OPTION=":z"
  fi
fi

# Build command when not running inside container
if ! $INSIDE_CONTAINER;then
  run_cmd="${CONTAINER_ENGINE} run --rm"

  # If running "environment" subcommand with apply or destroy, run as daemon
  if [ "$SUBCOMMAND" == "environment" ] && [[ "${ACTION}" == "apply" || "${ACTION}" == "destroy" ]];then
    run_cmd+=" -d"
  fi

  run_cmd+=" --cap-add=IPC_LOCK"

  if [ "${STATUS_DIR}" != "" ];then
    run_cmd+=" -v ${STATUS_DIR}:/data/status${SE_LINUX_OPTION}"
  fi

  if [ "${CONFIG_DIR}" != "" ];then
    run_cmd+=" -v ${CONFIG_DIR}:/data/config${SE_LINUX_OPTION}"
  fi

  if $SAT_DEVELOP;then run_cmd+=" -v ${PWD}:/sat-deployer";fi

  run_cmd+=" -e SUBCOMMAND=${SUBCOMMAND}"
  run_cmd+=" -e ACTION=${ACTION}"
  run_cmd+=" -e CONFIG_DIR=/data/config"
  run_cmd+=" -e STATUS_DIR=/data/status"
  run_cmd+=" -e IBM_CLOUD_API_KEY=${IBM_CLOUD_API_KEY}"

  if [ ! -z $VAULT_GROUP ];then
    run_cmd+=" -e VAULT_GROUP=${VAULT_GROUP}"
  fi

  if [ ! -z $VAULT_SECRET ];then
    run_cmd+=" -e VAULT_SECRET=${VAULT_SECRET} \
              -e VAULT_SECRET_VALUE=\"${VAULT_SECRET_VALUE}\" \
              -e VAULT_SECRET_FILE=${VAULT_SECRET_FILE}"
    if [ ! -z $VAULT_SECRET_FILE ];then
      run_cmd+=" -v ${VAULT_SECRET_FILE}:${VAULT_SECRET_FILE}${SE_LINUX_OPTION}"
    fi
  fi

  if [ ! -z $VAULT_PASSWORD ];then
    run_cmd+=" -e VAULT_PASSWORD=${VAULT_PASSWORD}"
  fi

  if [ ! -z $VAULT_CERT_CA_FILE ];then
    run_cmd+=" -e VAULT_CERT_CA_FILE=${VAULT_CERT_CA_FILE}"
    run_cmd+=" -v ${VAULT_CERT_CA_FILE}:${VAULT_CERT_CA_FILE}${SE_LINUX_OPTION}"
  fi

  if [ ! -z $VAULT_CERT_KEY_FILE ];then
    run_cmd+=" -e VAULT_CERT_KEY_FILE=${VAULT_CERT_KEY_FILE}"
    run_cmd+=" -v ${VAULT_CERT_KEY_FILE}:${VAULT_CERT_KEY_FILE}${SE_LINUX_OPTION}"
  fi

  if [ ! -z $VAULT_CERT_CERT_FILE ];then
    run_cmd+=" -e VAULT_CERT_CERT_FILE=${VAULT_CERT_CERT_FILE}"
    run_cmd+=" -v ${VAULT_CERT_CERT_FILE}:${VAULT_CERT_CERT_FILE}${SE_LINUX_OPTION}"
  fi

  run_cmd+=" -e ANSIBLE_VERBOSE=${ANSIBLE_VERBOSE}"
  run_cmd+=" -e ANSIBLE_STANDARD_OUTPUT=${ANSIBLE_STANDARD_OUTPUT}"
  run_cmd+=" -e CONFIRM_DESTROY=${CONFIRM_DESTROY}"
  run_cmd+=" -e CHECK_ONLY=${CHECK_ONLY}"

  # Handle extra variables
  if [ ${#arrExtraKey[@]} -ne 0 ];then
    for (( i=0; i<${#arrExtraKey[@]}; i++ ));do
      echo "Extra parameters ($i): ${arrExtraKey[$i]}=${arrExtraValue[$i]}"
      run_cmd+=" -e ${arrExtraKey[$i]}=${arrExtraValue[$i]}"
    done
    run_cmd+=" -e EXTRA_PARMS=\"${arrExtraKey[*]}\""
  fi

  if [[ "$SUBCOMMAND" == "environment" && "${ACTION}" == "command" ]];then
    run_cmd+=" -ti --entrypoint /sat-deployer/docker-scripts/env-command.sh"
  else
    run_cmd+=" --entrypoint /sat-deployer/docker-scripts/run_automation.sh"
  fi
  run_cmd+=" sat-deployer"

  # If running "environment" subcommand with apply/destroy, follow log
  if [ "$SUBCOMMAND" == "environment" ] && [[ "${ACTION}" == "apply" || "${ACTION}" == "destroy" ]];then
    CURRENT_CONTAINER_ID=$(eval $run_cmd)
    ACTIVE_CONTAINER_ID=${CURRENT_CONTAINER_ID}
    if [ "${STATUS_DIR}" != "" ];then
      echo "${CURRENT_CONTAINER_ID}" > ${STATUS_DIR}/pid/container.id
    fi
    run_env_logs
    sleep 3
    ${CONTAINER_ENGINE} container exists ${CURRENT_CONTAINER_ID}
    CONTAINER_STILL_RUNNING=$?
    if [ $CONTAINER_STILL_RUNNING -eq 0 ];then
      PODMAN_EXIT_CODE=$(${CONTAINER_ENGINE} inspect ${CURRENT_CONTAINER_ID} --format='{{.State.ExitCode}}')
    else
      PODMAN_EXIT_CODE=0
    fi
  else
    eval $run_cmd
    PODMAN_EXIT_CODE=$?
  fi

  exit $PODMAN_EXIT_CODE

# Run the below when sat-deploy.sh is started inside the container
else
  # Export extra variables
  if [ ${#arrExtraKey[@]} -ne 0 ];then
    for (( i=0; i<${#arrExtraKey[@]}; i++ ));do
      echo "Extra parameters ($i): ${arrExtraKey[$i]}=${arrExtraValue[$i]}"
      export ${arrExtraKey[$i]}="${arrExtraValue[$i]}"
    done
    export EXTRA_PARMS="${arrExtraKey[*]}"
    echo $EXTRA_PARMS
  fi
  . /sat-deployer/docker-scripts/run_automation.sh
fi