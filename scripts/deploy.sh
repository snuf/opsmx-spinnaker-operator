#!/bin/bash -xe
#
# 
#
type=$1
if [ "$type" != "k8s" -a "$type" != "oc" ]; then
  echo "$0: (k8s|oc)"
  exit 1
else
  if [ "type" == "k8s" ]; then
    type="kubectl"
  else
    type="oc"
  fi
fi


$type create -f ../deploy/crds/charts_v1alpha1_opsmxspinnakeroperator_crd.yaml -n operators
$type create -f ../deploy/service_account.yaml -n operators
$type create -f ../deploy/role.yaml -n operators
$type create -f ../deploy/role_binding.yaml -n operators
$type create -f ../deploy/operator.yaml -n operators
# kubectl create -f ../deploy/crds/charts_v1alpha1_opsmxspinnakeroperator_cr.yaml -n operators
$type create -f spinnaker.yaml -n operators

TRUE=true
while $TRUE; do
  kubectl -n operators get pods | grep spin-deck
  if [ "$?" == "0" ];then
    echo found spin-deck
    TRUE=false
  fi
  echo "waiting for spin-deck"
  sleep 1
done
kubectl -n operators patch svc spin-deck -p '{"spec":{"type": "NodePort" }}'
IP=$(minikube ip)
HALPOD=$(kubectl -n operators get pods | grep halyard | awk '{ print $1 }')
HALPORT=$(kubectl -n operators get svc/spin-deck | perl -ne 'if (/\d+:(\d+)/) { print $1 }')
for i in ui api; do
  cmd="hal config security $i edit \
    --override-base-url http://$IP:$HALPORT/gate"
  kubectl -n operators exec -ti $HALPOD -- bash -c "$cmd"
done
kubectl -n operators exec -ti $HALPOD -- bash -c "hal deploy apply"
NodePort=$(kubectl get svc/spin-deck -n operators -o yaml | grep nodePor | awk '{ print $3 }')
echo "Deck is running on http://$IP:$NodePort/
