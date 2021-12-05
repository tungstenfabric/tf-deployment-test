#!/bin/bash -ex

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

sudo systemctl stop 'openstack-*' httpd haproxy mariadb 'rabbitmq*' docker xinetd || true

# WA t oavoid error on next cleanup
# Error:
#  Problem: package python2-requests-2.20.0-3.module+el8.2.0+4577+feefd9b8.noarch requires python2-urllib3, but none of the providers can be installed
#   - package leapp-deps-el8-5.0.8-100.202109271224Z.b7ebfca.master.el8.noarch requires python2-requests, but none of the providers can be installed
#   - package python2-urllib3-1.24.2-3.module+el8.4.0+9193+f3daf6ef.noarch requires python2-pysocks, but none of the providers can be installed
#   - package python2-leapp-0.13.0-1.el7_9.noarch requires leapp-framework-dependencies = 3, but none of the providers can be installed
#   - conflicting requests
#   - problem with installed package python2-leapp-0.13.0-1.el7_9.noarch
sudo rpm -e --nodeps python2-leapp || true
sudo rpm -e --nodeps leapp || true
sudo rpm -e --nodeps leapp-upgrade-el7toel8 || true

sudo yum -y remove '*el7ost*' 'galera*' 'haproxy*' \
    httpd 'mysql*' 'pacemaker*' xinetd python-jsonpointer \
    qemu-kvm-common-rhev qemu-img-rhev 'rabbit*' \
    'redis*' \
    -- \
    -'*openvswitch*' -python-docker -python-PyMySQL \
    -python-pysocks -python2-asn1crypto -python2-babel \
    -python2-cffi -python2-cryptography -python2-dateutil \
    -python2-idna -python2-ipaddress -python2-jinja2 \
    -python2-jsonpatch -python2-markupsafe -python2-pyOpenSSL \
    -python2-requests -python2-six -python2-urllib3 \
    -python-httplib2 -python-passlib -python2-netaddr -ceph-ansible

sudo dnf -y remove python2* || true

if [[ "${ENABLE_RHEL_REGISTRATION,,}" == 'true' ]] ; then
  #Red Hat Registration case
  ##6.1. LOCKING THE ENVIRONMENT TO A RED HAT ENTERPRISE LINUX RELEASE
  sudo subscription-manager release --set=${RHEL_VERSION//rhel/}
  sudo subscription-manager repos --disable=*
  sudo subscription-manager repos \
    --enable=rhel-8-for-x86_64-baseos-rpms \
    --enable=rhel-8-for-x86_64-appstream-rpms \
    --enable=rhel-8-for-x86_64-highavailability-rpms \
    --enable=fast-datapath-for-rhel-8-x86_64-rpms \
    --enable=ansible-2-for-rhel-8-x86_64-rpms \
    --enable=openstack-${RHOSP_VERSION//rhosp/}-for-rhel-8-x86_64-rpms \
    --enable=satellite-tools-6.5-for-rhel-8-x86_64-rpms \
    --enable=advanced-virt-for-rhel-8-x86_64-rpms
fi

declare -A _dnf_container_tools=(
  ["rhel8.2"]="container-tools:2.0"
  ["rhel8.4"]="container-tools:3.0"
)
_ctools=${_dnf_container_tools[$RHEL_VERSION]}
if [ -z "$_ctools" ] ; then
  echo "ERROR: internal error - no container-tools set for $RHEL_VERSION"
  exit 1
fi
sudo dnf module disable -y container-tools:rhel8
sudo dnf module enable -y $_ctools
sudo dnf module disable -y virt:rhel
sudo dnf module enable -y virt:8.2

#this package blocks dystro-sync
sudo dnf remove -y crypto-policies-scripts-20210209-1.gitbfb6bed.el8_3.noarch || true

sudo dnf distro-sync -y

echo "Perform reboot: sudo reboot"
echo $(date) "------------------ FINISHED: $0 ------------------"
