#!/bin/bash -eux

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

/sbin/ip addr list

#5.1. REMOVING RED HAT OPENSTACK PLATFORM DIRECTOR PACKAGES
sudo systemctl stop openstack-* httpd haproxy mariadb rabbitmq* docker xinetd || true

sudo yum -y remove *el7ost* galera* haproxy* \
    httpd mysql* pacemaker* xinetd python-jsonpointer \
    qemu-kvm-common-rhev qemu-img-rhev rabbit* \
    redis* \
    -- \
    -*openvswitch* -python-docker -python-PyMySQL \
    -python-pysocks -python2-asn1crypto -python2-babel \
    -python2-cffi -python2-cryptography -python2-dateutil \
    -python2-idna -python2-ipaddress -python2-jinja2 \
    -python2-jsonpatch -python2-markupsafe -python2-pyOpenSSL \
    -python2-requests -python2-six -python2-urllib3 \
    -python-httplib2 -python-passlib -python2-netaddr -ceph-ansible

sudo rm -rf /etc/httpd /var/lib/docker

#5.2. PERFORMING A LEAPP UPGRADE ON THE UNDERCLOUD
sudo yum install -y leapp

sudo tar -xzf $my_dir/../redhat_files/leapp-data8.tar.gz -C /etc/leapp/files

sudo subscription-manager refresh

echo 'openvswitch2.11' | sudo tee -a /etc/leapp/transaction/to_remove
echo 'openvswitch2.13' | sudo tee -a /etc/leapp/transaction/to_install
echo 'ceph-ansible' | sudo tee -a /etc/leapp/transaction/to_keep

sudo leapp upgrade --debug \
  --enablerepo rhel-8-for-x86_64-baseos-rpms \
  --enablerepo rhel-8-for-x86_64-appstream-rpms \
  --enablerepo rhel-8-for-x86_64-highavailability-rpms \
  --enablerepo fast-datapath-for-rhel-8-x86_64-rpms \
  --enablerepo ansible-2-for-rhel-8-x86_64-rpms \
  --enablerepo openstack-16.1-for-rhel-8-x86_64-rpms \
  --enablerepo satellite-tools-6.5-for-rhel-8-x86_64-rpms

sudo touch /.autorelabel

echo "Perform reboot: sudo reboot"
echo $(date) "------------------ FINISHED: $0 ------------------"
