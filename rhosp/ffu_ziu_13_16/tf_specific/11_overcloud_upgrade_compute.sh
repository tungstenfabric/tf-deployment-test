  # use separate steps for system_upgrade_prepare + system_upgrade_run
  # instead of united system_upgrade to allow some hack for vhost0
  openstack overcloud upgrade run --stack overcloud --tags system_upgrade_prepare --limit $node
  openstack overcloud upgrade run --stack overcloud --tags system_upgrade_run --limit $node
