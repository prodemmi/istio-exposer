#!/bin/bash

# === Script: istio-exposer.sh ===
# Author: Emad Malekpour — https://malekpour-dev.ir
# Description: Automatically exposes a Kubernetes service using Istio VirtualService & Gateway

# Default values
SERVICE_NAME=""
NAMESPACE="default"
SERVICE_PORT=80
PUBLIC_PATH="/"
ENV="dev"
GATEWAY_NAME="default-gateway"
VIRTUAL_SERVICE_NAME=""
SECRET=""

# Parse flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--name) SERVICE_NAME="$2"; shift ;;
        -s|--namespace) NAMESPACE="$2"; shift ;;
        -p|--port) SERVICE_PORT="$2"; shift ;;
        --path) PUBLIC_PATH="$2"; shift ;;
        --env) ENV="$2"; shift ;;
        --secret) SECRET="$2"; shift ;;
        -h|--help)
            echo "🧩 istio-exposer.sh - Istio Service Exposer"
            echo "Author: Emad Malekpour — https://malekpour-dev.ir"
            echo ""
            echo "Usage:"
            echo "  ./istio-exposer.sh --name <svc> [--namespace default] [--port 3000] [--path /path] [--env dev|prod]"
            echo ""
            echo "Flags:"
            echo "  -n, --name        Kubernetes service name (required)"
            echo "  -s, --namespace   Namespace of the service (default: default)"
            echo "  -p, --port        Service port (default: 80)"
            echo "      --path        Public path to expose (default: /)"
            echo "      --env         Environment: dev or prod (default: dev)"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "🔗 More info & full README: https://github.com/prodemmi/istio-exposer"
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

if [[ "$ENV" == "dev" ]]; then
    echo "✅ [dev] Creating Gateway $GATEWAY_NAME ..."
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: $GATEWAY_NAME
  namespace: $NAMESPACE
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
EOF

if [[ -n "$SECRET" ]]; then
  # Patch the gateway to add 443 server
  kubectl patch gateway $GATEWAY_NAME -n $NAMESPACE --type='json' -p='[{
    "op": "add",
    "path": "/spec/servers/-",
    "value": {
      "port": {
        "number": 443,
        "name": "https",
        "protocol": "HTTPS"
      },
      "tls": {
        "mode": "SIMPLE",
        "credentialName": "'"$SECRET"'"
      },
      "hosts": ["*"]
    }
  }]'
fi

else
    echo "✅ [prod] Using default istio-ingressgateway (no need to create gateway)"
    GATEWAY_NAME="istio-ingress/ingressgateway"
fi

echo "✅ Creating VirtualService $VIRTUAL_SERVICE_NAME ..."

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: $VIRTUAL_SERVICE_NAME
  namespace: $NAMESPACE
spec:
  hosts:
  - "*"
  gateways:
  - $GATEWAY_NAME
  http:
  - match:
    - uri:
        prefix: $PUBLIC_PATH
    rewrite:
      uri: /
    route:
    - destination:
        host: ${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local
        port:
          number: $SERVICE_PORT
EOF

if [[ "$ENV" == "dev" ]]; then
  echo "🔧 Patching istio-ingressgateway to NodePort..."
  kubectl patch svc istio-ingressgateway -n istio-ingress -p '{"spec": {"type": "NodePort"}}'
else
  echo "🔧 Ensuring istio-ingressgateway is LoadBalancer..."
  kubectl patch svc istio-ingressgateway -n istio-ingress -p '{"spec": {"type": "LoadBalancer"}}'
fi

# Print output address
HTTP_NODE_PORT=$(kubectl get svc istio-ingressgateway -n istio-ingress -o=jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
HTTPS_NODE_PORT=$(kubectl get svc istio-ingressgateway -n istio-ingress -o=jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
NODE_IP=$(kubectl get nodes -o=jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
echo "🌐 Your service is now available at:"
echo "👉 http://${NODE_IP}:${HTTP_NODE_PORT}${PUBLIC_PATH}"
echo "👉 https://${NODE_IP}:${HTTPS_NODE_PORT}${PUBLIC_PATH}"
