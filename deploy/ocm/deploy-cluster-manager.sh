#!/bin/bash

PROJECT_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/../.. && pwd )"

source ${PROJECT_HOME}/deploy/vks/config.sh

###############################################################################################
#               Functions
###############################################################################################

deploy_vks_manifests() {
    kubectl --kubeconfig=${VKS_HOME}/admin.conf apply -f ${PROJECT_HOME}/deploy/ocm/vks-manifests
}

deploy_cluster_manager() {
    kubectl apply -n ${VKS_NS} -f ${PROJECT_HOME}/deploy/ocm/host-manifests
    kubectl -n ${VKS_NS} wait --for=condition=available --timeout=600s deployment/cluster-manager-registration-controller
}

get_kind_cluster_ip() {
    docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${KIND_CLUSTER_NAME}-control-plane
}

get_bootstrap_token() {
   secret_name=$(kubectl --kubeconfig=${VKS_HOME}/admin.conf get sa -n open-cluster-management cluster-bootstrap -o json | jq -r '.secrets[0].name')
   token=$(kubectl --kubeconfig=${VKS_HOME}/admin.conf get secret -n open-cluster-management ${secret_name} -o json | jq -r '.data.token' | base64 -d)
   echo $token
}

###########################################################################################
#                   Main   
###########################################################################################

unset KUBECONFIG

deploy_vks_manifests

deploy_cluster_manager

if [ ! -z "$1" ]; then
    echo "External IP $1 has been provided, using for join command generation"
    hubApiserver=https://$1:${KIND_CLUSTER_NODEPORT}
else
    # TODO - improve detection of host IP
    if [ "$USE_KIND" == "true" ]; then 
        case "$OSTYPE" in
            darwin*)  CLUSTER_IP=$(ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}' | head -n 1 ) ;; 
            linux*)   CLUSTER_IP=$(get_kind_cluster_ip) ;;
            *)        echo "unknown: $OSTYPE" ;;
        esac
        hubApiserver=https://${CLUSTER_IP}:${KIND_CLUSTER_NODEPORT}
    fi
fi

token=$(get_bootstrap_token)

echo ""
echo "cluster manager has been started! To join clusters run the command (make sure to use the correct <cluster-name>:"
echo ""
echo "clusteradm join --hub-token ${token} --hub-apiserver ${hubApiserver} --cluster-name <cluster-name>"
