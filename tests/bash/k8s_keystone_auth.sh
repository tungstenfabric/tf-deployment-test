#!/bin/bash

# install neccessary packages
# TODO(tikitavi): where to move installation
sudo snap install kubectl --classic
sudo snap install client-keystone-auth --edge
sudo apt-get -y install python-openstackclient

# copy kubeconfig from worker
mkdir -p ~/.kube
k8s_worker=$(juju status | grep 'kubernetes-worker/' | head -n 1 | awk '{print$1}' | sed 's/*//g')
juju scp ${k8s_worker}:/home/ubuntu/.kube/config ~/.kube/config

# enable snat
kubectl get ns default -o yaml > ns.yaml
sed -i 's/metadata:/metadata:\n  annotations:\n    opencontrail.org\/ip_fabric_snat: "true"\n/g' ns.yaml
kubectl replace -f ns.yaml

# configure context for keystone auth
kubectl config set-context keystone --user=keystone-user --cluster=juju-cluster
kubectl config use-context keystone
kubectl config set-credentials keystone-user --exec-command=/snap/bin/client-keystone-auth
kubectl config set-credentials keystone-user --exec-api-version=client.authentication.k8s.io/v1beta1

# export the correct address to keystone
source stackrc

# test kubectl in keystone context
kubectl get pods -A
if [[ $? != '0' ]] ; then
    echo "ERROR: kubectl isn't authorized"
    kubectl config use-context juju-context
    exit 1
fi

# test kubectl with k8s user (user is absent, the kubectl should fail)
random=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
K8S_USER="user_$random"
K8S_PASSWORD="$random"
K8S_PROJECT_NAME="k8s"

cat stackrc > stackrc_demo_user
sed -i "s/export OS_USERNAME=.*/export OS_USERNAME=$K8S_USER/g" stackrc_demo_user
sed -i "s/export OS_PASSWORD=.*/export OS_PASSWORD=$K8S_PASSWORD/g" stackrc_demo_user
sed -i "s/export OS_PROJECT_NAME=.*/export OS_PROJECT_NAME=$K8S_PROJECT_NAME/g" stackrc_demo_user

source stackrc_demo_user

kubectl get pods -A
if [[ $? == '0' ]] ; then
    echo "ERROR: kubectl should fail, user is absent, but didn't"
    kubectl config use-context juju-context
    exit 1
fi

# add k8s project and user
source stackrc

openstack project create --domain $OS_DOMAIN_NAME $K8S_PROJECT_NAME
openstack user create --project $K8S_PROJECT_NAME --project-domain $OS_PROJECT_DOMAIN_NAME --password $K8S_PASSWORD --domain $OS_DOMAIN_NAME $K8S_USER
openstack role add --project $K8S_PROJECT_NAME --project-domain $OS_PROJECT_DOMAIN_NAME --user $K8S_USER --user-domain $OS_USER_DOMAIN_NAME  admin

# test kubectl with k8s user
source stackrc_demo_user

kubectl get pods -A
if [[ $? != '0' ]] ; then
    echo "ERROR: kubectl isn't authorized"
    kubectl config use-context juju-context
    exit 1
fi

# remove project/user/role for idempotence
source stackrc
kubectl config use-context juju-context
openstack role remove --user $K8S_USER --project $K8S_PROJECT_NAME admin
openstack user delete $K8S_USER
openstack project delete $K8S_PROJECT_NAME
