source "./.tf/stack.env"

# ----------------- from repo: tf-dev-test
TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}
TF_STACK_PROFILE="${TF_CONFIG_DIR}/stack.env"
# -----------------
if [ -e "$TF_STACK_PROFILE" ] ; then
  cat "$TF_STACK_PROFILE"
  source "$TF_STACK_PROFILE"
fi
# -----------------
export SSH_OPTIONS=${SSH_OPTIONS:-"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"}