#!/usr/bin/env bash

set -uo pipefail

UAA_INGRESS_IP=""
UAA_ADMIN_CLIENT_SECRET=""

ytt_and_minikube() {
  local ytt_kubectl_cmd="ytt -f templates -f addons -v admin.client_secret=${UAA_ADMIN_CLIENT_SECRET} ${@} | kubectl apply -f -"

  echo "Running '${ytt_kubectl_cmd}'"
  eval "${ytt_kubectl_cmd}"
}

wait_for_ingress() {
  echo "Waiting for ingress availability"

  local get_ip_cmd="kubectl get ingress -o json | jq '.items[0].status.loadBalancer.ingress[0].ip' -e -r"
  local ip
  ip=$(eval "${get_ip_cmd}")

  while [ $? -ne 0 ]; do
    echo "Checking for ingress ip... ${ip}"
    sleep 2
    ip=$(eval "${get_ip_cmd}")
  done

  echo "Checking for ingress ip... ${ip}"
  UAA_INGRESS_IP="${ip}"
}

wait_for_availability() {
  echo "Waiting for UAA availability"

  local status_cmd="kubectl get deployments/uaa -o json | jq '.status.readyReplicas' -e"
  local count_ready=
  count_ready=$(eval "${status_cmd}")

  while [ $? -ne 0 ]; do
    echo "Waiting for UAA availability"
    sleep 2
    count_ready=$(eval "${status_cmd}")
  done

  while [ 1 -gt ${count_ready} ]; do
    echo "Waiting for UAA availability"
    sleep 2
    count_ready=$(eval "${status_cmd}")
  done
}

target_uaa() {
  echo "Attempting to target the UAA"

  local target_cmd="uaa target 'http://${UAA_INGRESS_IP}' --skip-ssl-validation"
  eval "${target_cmd}"

  while [ $? -ne 0 ]; do
    echo "Attempting to target the UAA"
    sleep 2
    eval "${target_cmd}"
  done
}

main() {
  UAA_ADMIN_CLIENT_SECRET="$(openssl rand -hex 12)"
  ytt_and_minikube "${@}"
  wait_for_ingress
  wait_for_availability
  target_uaa ${UAA_INGRESS_IP}
  uaa get-client-credentials-token admin -s "${UAA_ADMIN_CLIENT_SECRET}"
}

main $@
