#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
PROFILE="assumed-role"
PROJECTS=($(echo $output | jq -r '. | to_entries[] | select(.key|endswith("_projects")) | .value.value[]'))
EKS_CLUSTER_NAMES=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names\")) | .value.value | to_entries[] | (.value)")
REGIONS=$(echo $output |jq -r ".| to_entries[] | select(.key|endswith(\"_regions\")) | .value.value | to_entries[] | (.value)")

echo "Authenticating to EKS Cluster ${EKS_CLUSTER_NAMES} - ${REGIONS}"
# get identity
aws sts get-caller-identity
# add EKS cluster to $HOME/.kube/config
echo "aws eks --region $REGIONS update-kubeconfig --name $EKS_CLUSTER_NAMES --alias \"${EKS_CLUSTER_NAMES##*-}\" "
aws eks --region $REGIONS update-kubeconfig --name $EKS_CLUSTER_NAMES --alias "${EKS_CLUSTER_NAMES##*-}" 
echo
echo "Create Aliases"
echo "  alias: ${EKS_CLUSTER_NAMES##*-} =  kubectl config use-context ${EKS_CLUSTER_NAMES##*-}"
alias $(echo ${EKS_CLUSTER_NAMES##*-})="kubectl config use-context ${EKS_CLUSTER_NAMES##*-}"
alias 'kt=kubectl -n tasky'
alias 'kk=kubectl -n kube-system'
alias 'k=kubectl'