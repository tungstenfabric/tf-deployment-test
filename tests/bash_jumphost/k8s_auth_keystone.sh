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
. stackrc
auth_ip=$(juju config keystone os-public-hostname)
export OS_AUTH_URL=http://$auth_ip:5000/v3

# test kubectl in keystone context
kubectl get pods -A
if [[ $? != '0' ]] ; then
    echo "ERROR: kubectl isn't authorized"
    exit 1
fi

# test kubectl with k8s user (user is absent, the kubectl should fail)
export OS_USERNAME=k8s_user
export OS_PASSWORD=k8s_password
export OS_PROJECT_NAME=k8s

kubectl get pods -A
if [[ $? == '0' ]] ; then
    echo "ERROR: kubectl should fail, user is absent, but didn't"
    exit 1
fi

# add k8s project and user
export OS_USERNAME=admin
export OS_PASSWORD=password
export OS_PROJECT_NAME=admin

openstack project create --domain admin_domain k8s
openstack user create --project k8s --project-domain admin_domain --password k8s_password --domain admin_domain k8s_user
openstack role add --user k8s_user --user-domain admin_domain --project k8s --project-domain admin_domain admin

# test kubectl with k8s user
export OS_USERNAME=k8s_user
export OS_PASSWORD=k8s_password
export OS_PROJECT_NAME=k8s

kubectl get pods -A
if [[ $? != '0' ]] ; then
    echo "ERROR: kubectl isn't authorized"
    exit 1
fi

# TODO(tikitavi): remove project/user/role for idempotence
