#!/bin/bash -eux

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

sudo dnf -y remove python2*

#6.1. LOCKING THE ENVIRONMENT TO A RED HAT ENTERPRISE LINUX RELEASE
sudo subscription-manager release --set=8.2
sudo subscription-manager repos --disable=*
sudo subscription-manager repos \
  --enable=rhel-8-for-x86_64-baseos-rpms \
  --enable=rhel-8-for-x86_64-appstream-rpms \
  --enable=rhel-8-for-x86_64-highavailability-rpms \
  --enable=fast-datapath-for-rhel-8-x86_64-rpms \
  --enable=ansible-2-for-rhel-8-x86_64-rpms \
  --enable=openstack-16.1-for-rhel-8-x86_64-rpms \
  --enable=satellite-tools-6.5-for-rhel-8-x86_64-rpms

sudo dnf module disable -y container-tools:rhel8
sudo dnf module enable -y container-tools:2.0
#https://bugzilla.redhat.com/show_bug.cgi?id=1883379
#sudo dnf module disable -y virt:rhel
#sudo dnf module enable -y virt:8.2

sudo dnf distro-sync -y 

echo "Perform reboot: sudo reboot"
echo $(date) "------------------ FINISHED: $0 ------------------"
