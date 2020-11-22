function wait_cmd_success() {
    i=0
    while eval $3; do
        sleep $1
        printf "."
        i=$((i + 1))
        if (( i >= $2 )); then
            echo -e "\nERROR: wait failed in $((i*$1))s"
            exit 1
        fi
    done
    echo -e "\nINFO: done in $((i*$1))s"
}

function check_tf_active() {
  local machine
  local line=
  for machine in $(echo "$CONTROLLER_NODES $AGENT_NODES" | tr " " "\n" | sort -u) ; do
    if ! ssh $SSH_OPTIONS $machine "command -v contrail-status" 2>/dev/null ; then
      return 1
    fi
    for line in $(ssh $SSH_OPTIONS $machine "sudo contrail-status" 2>/dev/null | egrep ": " | grep -v "WARNING" | awk '{print $2}'); do
      if [ "$line" != "active" ] && [ "$line" != "backup" ] ; then
        return 1
      fi
    done
  done
  return 0
}

function check_tag() {
  local tag=$1
  local machine
  local line=
  for machine in $(echo "$CONTROLLER_NODES $AGENT_NODES" | tr " " "\n" | sort -u) ; do
    # TODO(tikitavi): rework check for json parse
    for line in $(ssh $SSH_OPTIONS $machine "sudo contrail-status" 2>/dev/null | egrep "running" | awk '{print $4}'); do
      if [ "$line" != "$tag" ] ; then
        return 1
      fi
    done
  done
  return 0
}

# pull deployer src container locally and extract files to path
# Functions get two required params:
#  - deployer image
#  - directory path deployer have to be extracted to
function fetch_deployer() {
  if [[ $# != 2 ]] ; then
    echo "ERROR: Deployer image name and path to deployer directory are required for fetch_deployer"
    return 1
  fi

  local deployer_image=$1
  local deployer_dir=$2

  sudo rm -rf $deployer_dir

  local image="$CONTAINER_REGISTRY/$deployer_image"
  [ -n "$CONTRAIL_CONTAINER_TAG" ] && image+=":$CONTRAIL_CONTAINER_TAG"
  sudo docker create --name $deployer_image --entrypoint /bin/true $image || return 1
  sudo docker cp $deployer_image:/src $deployer_dir
  sudo docker rm -fv $deployer_image
  sudo chown -R $UID $deployer_dir
}
