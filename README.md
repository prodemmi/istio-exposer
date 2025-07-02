# 🧩 istio-exposer.sh

> Simple script to expose any Kubernetes service via Istio Gateway & VirtualService  
> Author: **Emad Malekpour** — [malekpour-dev.ir](https://malekpour-dev.ir)

---

## 📦 Features

- Automatically creates a Gateway (only in dev)
- Sets correct service type (`NodePort` for dev, `LoadBalancer` for prod)
- Supports custom paths and ports
- Easy integration with any Istio-enabled cluster
- No YAMLs to write manually!

---

## ⚙️ Usage

```bash
git clone https://github.com/prodemmi/istio-exposer

cd istio-exposer && chmod +x istio-exposer.sh

./istio-exposer.sh \
  --name <service-name> \
  --namespace <namespace> \
  --port <service-port> \
  --path <public-path> \
  --env dev|prod
```

## Example
```bash
./istio-exposer.sh \
  --name version-viewer \
  --namespace default \
  --port 3000 \
  --path / \
  --env dev
```

This will:
- Create a Gateway (in dev mode)
- Create a VirtualService for path /
- Patch istio-ingressgateway to NodePort (in dev mode)

Print access URL like:
http://<node-ip>:<node-port>/

## Flags
| Flag                | Description                        | Default      |
| ------------------- | ---------------------------------- | ------------ |
| `--name`, `-n`      | Kubernetes service name            | **Required** |
| `--namespace`, `-s` | Namespace of the service           | `default`    |
| `--port`, `-p`      | Internal port of the service       | `80`         |
| `--path`            | External public path (e.g. `/api`) | `/`          |
| `--env`             | Environment: `dev` or `prod`       | `dev`        |


## ☁️ How It Works
- In dev mode:
    - Creates a custom Gateway
    - Exposes ingressgateway as NodePort

- In prod mode:
    - Reuses default istio-ingressgateway
    - Ensures it’s of type LoadBalancer

