#!/bin/bash -eux

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh
source $my_dir/../../common/functions.sh

/sbin/ip addr list

#4.5. Converting to next generation power management drivers
OLDDRIVER="pxe_ipmitool"
NEWDRIVER="ipmi"
for NODE in $(openstack baremetal node list --driver $OLDDRIVER -c UUID -f value) ; do
    retry 5 openstack baremetal node set $NODE --driver $NEWDRIVER
done


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

#Local mirrors case (CICD)
#copy local.repo file for overcloud nodes
cp /etc/yum.repos.d/local.repo /tmp/
cat $my_dir/../redhat_files/rhel8.repo.template | envsubst > $my_dir/../redhat_files/rhel8.repo
sudo rm -f /etc/yum.repos.d/*
sudo cp $my_dir/../redhat_files/rhel8.repo /etc/yum.repos.d/


echo 'openvswitch2.11' | sudo tee -a /etc/leapp/transaction/to_remove
echo 'openvswitch2.13' | sudo tee -a /etc/leapp/transaction/to_install
echo 'ceph-ansible' | sudo tee -a /etc/leapp/transaction/to_keep

#Red Hat Registration case
#sudo subscription-manager refresh
#sudo leapp upgrade --debug \
#  --enablerepo rhel-8-for-x86_64-baseos-rpms \
#  --enablerepo rhel-8-for-x86_64-appstream-rpms \
#  --enablerepo rhel-8-for-x86_64-highavailability-rpms \
#  --enablerepo fast-datapath-for-rhel-8-x86_64-rpms \
#  --enablerepo ansible-2-for-rhel-8-x86_64-rpms \
#  --enablerepo openstack-16.1-for-rhel-8-x86_64-rpms \
#  --enablerepo satellite-tools-6.5-for-rhel-8-x86_64-rpms

#Local mirrors case (CICD)
sudo leapp upgrade --no-rhsm --debug \
  --enablerepo rhel-8-for-x86_64-baseos-rpms \
  --enablerepo rhel-8-for-x86_64-appstream-rpms \
  --enablerepo rhel-8-for-x86_64-highavailability-rpms \
  --enablerepo fast-datapath-for-rhel-8-x86_64-rpms \
  --enablerepo ansible-2.9-for-rhel-8-x86_64-rpms \
  --enablerepo openstack-16.1-for-rhel-8-x86_64-rpms \
  --enablerepo satellite-tools-6.5-for-rhel-8-x86_64-rpms \
  --enablerepo advanced-virt-for-rhel-8-x86_64-rpms


sudo touch /.autorelabel

echo "Perform reboot: sudo reboot"
echo $(date) "------------------ FINISHED: $0 ------------------"
