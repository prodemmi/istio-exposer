#!/bin/bash

# === Script: istio-exposer-delete.sh ===
# Author: Emad Malekpour — https://malekpour-dev.ir
# Description: Deletes Istio Gateway & VirtualService created by istio-exposer.sh

SERVICE_NAME=""
NAMESPACE="default"
ENV="dev"
GATEWAY_NAME=""
VIRTUAL_SERVICE_NAME=""

# Parse flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--name) SERVICE_NAME="$2"; shift ;;
        -s|--namespace) NAMESPACE="$2"; shift ;;
        --env) ENV="$2"; shift ;;
        -h|--help)
            echo "🧩 istio-exposer-delete.sh - Delete Istio Resources"
            echo "Usage:"
            echo "  ./istio-exposer-delete.sh --name <svc> [--namespace default] [--env dev|prod]"
            exit 0
            ;;
        *) echo "❌ Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$SERVICE_NAME" ]]; then
    echo "❌ Service name is required. Use --name or -n"
    exit 1
fi

VIRTUAL_SERVICE_NAME="${SERVICE_NAME}-vs"
GATEWAY_NAME="${SERVICE_NAME}-gateway"

echo "🗑️ Deleting VirtualService $VIRTUAL_SERVICE_NAME in namespace $NAMESPACE ..."
kubectl delete virtualservice $VIRTUAL_SERVICE_NAME -n $NAMESPACE --ignore-not-found

if [[ "$ENV" == "dev" ]]; then
  echo "🗑️ Deleting Gateway $GATEWAY_NAME in namespace $NAMESPACE ..."
  kubectl delete gateway $GATEWAY_NAME -n $NAMESPACE --ignore-not-found

  echo "🔧 Optionally, patch istio-ingressgateway service type back to LoadBalancer..."
  kubectl patch svc istio-ingressgateway -n istio-ingress -p '{"spec": {"type": "LoadBalancer"}}'
fi

echo "✅ Done."
