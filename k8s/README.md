# AgentGateway Kubernetes Deployment

Official kgateway-based deployment guide for AgentGateway on Kubernetes with Gateway API.

## Overview

This deployment uses the **kgateway control plane**, which is the official and recommended way to deploy AgentGateway on Kubernetes. It leverages the Kubernetes Gateway API for declarative configuration and automatic proxy lifecycle management.

## Quick Start

### Prerequisites

- Kubernetes cluster (GKE, EKS, AKS, or local)
- `kubectl` configured
- `helm` installed
- cert-manager installed for SSL certificates
- nginx-ingress controller installed

### 1. Set up secrets

```bash
kubectl create secret generic agentgateway-secrets \
  --from-literal=openai-api-key=YOUR_OPENAI_API_KEY \
  --namespace=agentgateway-system
```

### 2. Install Gateway API CRDs

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
```

### 3. Install kgateway control plane

```bash
# Create namespace
kubectl create namespace agentgateway-system

# Install kgateway CRDs
helm upgrade -i agentgateway-crds oci://ghcr.io/kgateway-dev/charts/agentgateway-crds \
  --namespace agentgateway-system \
  --version v2.2.0-main \
  --wait

# Install kgateway control plane
helm upgrade -i agentgateway oci://ghcr.io/kgateway-dev/charts/agentgateway \
  --namespace agentgateway-system \
  --version v2.2.0-main \
  --values kgateway-values.yaml \
  --wait
```

### 4. Deploy AgentGateway configuration

```bash
# Apply SSL cluster issuer
kubectl apply -f cluster-issuer.yaml

# Apply AgentGateway configuration
kubectl apply -f agentgateway-params.yaml

# Apply Gateway and routing
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml

# Apply UI service and ingress
kubectl apply -f ui-service.yaml
kubectl apply -f ui-ingress.yaml
```

### 5. Verify deployment

```bash
# Check Gateway status
kubectl get gateway -n agentgateway-system

# Check proxy pods
kubectl get pods -n agentgateway-system -l gateway.networking.k8s.io/gateway-name=agentgateway

# Check services
kubectl get svc -n agentgateway-system
```

## Files Overview

### Active Files (kgateway-based)

| File | Purpose |
|------|---------|
| `kgateway-values.yaml` | Helm values for kgateway control plane |
| `agentgateway-params.yaml` | AgentgatewayParameters CRD configuration |
| `gateway.yaml` | Gateway API Gateway resource |
| `httproute.yaml` | Gateway API HTTPRoute for API traffic |
| `ui-service.yaml` | Service for UI access |
| `ui-ingress.yaml` | Ingress for UI subdomain |
| `cluster-issuer.yaml` | Let's Encrypt certificate issuer |
| `secrets-template.yaml` | Template for creating secrets |
| `cleanup-old.sh` | Script to remove old standalone deployment |

### Deprecated Files (kept for reference)

| File | Status |
|------|--------|
| `deployment.yaml` | ⚠️ DEPRECATED - Use kgateway instead |
| `configmap.yaml` | ⚠️ DEPRECATED - Use agentgateway-params.yaml |
| `service.yaml` | ⚠️ DEPRECATED - Auto-created by Gateway API |
| `ingress.yaml` | ⚠️ DEPRECATED - Use httproute.yaml and ui-ingress.yaml |

## Architecture

```
┌─────────────────────────────────────────────┐
│         kgateway Control Plane              │
│  (Manages proxy lifecycle via Gateway API) │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│           Gateway Resource                  │
│  (References AgentgatewayParameters)        │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│       agentgateway Proxy Pods               │
│  (Auto-provisioned by kgateway)             │
└──────┬──────────────────────────────┬───────┘
       │                              │
       ▼                              ▼
┌──────────────┐            ┌──────────────────┐
│  HTTPRoute   │            │   UI Service     │
│  (API/3000)  │            │   (Admin/15000)  │
└──────┬───────┘            └────────┬─────────┘
       │                              │
       ▼                              ▼
  agentgateway.                ui.agentgateway.
  prometheusags.ai             prometheusags.ai
```

## Configuration

### AgentgatewayParameters

The `agentgateway-params.yaml` file defines:
- **Logging**: JSON format with CEL expressions
- **Binds/Listeners**: Port 3000 for HTTP traffic
- **Routes**: Health check and main AI routes
- **Backends**: OpenAI integration

### Gateway API Resources

- **Gateway**: Entry point for traffic, references AgentgatewayParameters
- **HTTPRoute**: Routing rules for API traffic
- **UI Service**: Exposes admin port (15000) for UI access
- **UI Ingress**: Separate subdomain for UI

## Access Points

After deployment:
- **API**: `https://agentgateway.prometheusags.ai`
- **Health**: `https://agentgateway.prometheusags.ai/health`
- **UI**: `https://ui.agentgateway.prometheusags.ai/ui`

### Local UI Access (Port-forward)

```bash
kubectl port-forward svc/agentgateway-ui 15000:15000 -n agentgateway-system
# Then open: http://localhost:15000/ui
```

## SSL Certificates

SSL is automatically managed by cert-manager with Let's Encrypt:
- **API Domain**: `agentgateway.prometheusags.ai`
- **UI Domain**: `ui.agentgateway.prometheusags.ai`
- **Challenge**: HTTP-01
- **Renewal**: Automatic

## GitHub Actions

The deployment workflow (`.github/workflows/deploy.yml`) automatically:
- Builds multi-arch Docker images
- Pushes to Docker Hub (`docker.io/tribehealth/agentgateway`)
- Installs kgateway control plane
- Deploys Gateway API resources
- Verifies both API and UI health

Required GitHub secrets:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `GCP_SA_KEY` (for GKE authentication)

Required GitHub variables:
- `GKE_CLUSTER`
- `GKE_REGION`
- `GCP_PROJECT`

## Health Checks

The deployment includes comprehensive health checks:
- **Readiness probe**: Port 15021 on proxy pods
- **API health**: `/health` endpoint on port 3000
- **UI health**: `/ui` endpoint on port 15000
- **External verification**: Both public URLs

## Troubleshooting

### Check Gateway status
```bash
kubectl describe gateway agentgateway -n agentgateway-system
```

### Check proxy pods
```bash
kubectl get pods -n agentgateway-system -l gateway.networking.k8s.io/gateway-name=agentgateway
kubectl logs -f -l gateway.networking.k8s.io/gateway-name=agentgateway -n agentgateway-system
```

### Check HTTPRoute
```bash
kubectl describe httproute agentgateway-routes -n agentgateway-system
```

### Check certificates
```bash
kubectl get certificate -n agentgateway-system
kubectl describe certificate -n agentgateway-system
```

### View kgateway controller logs
```bash
kubectl logs -f deployment/agentgateway -n agentgateway-system
```

### Port-forward for testing
```bash
# Test API
kubectl port-forward svc/agentgateway 8080:3000 -n agentgateway-system
curl http://localhost:8080/health

# Test UI
kubectl port-forward svc/agentgateway-ui 15000:15000 -n agentgateway-system
curl http://localhost:15000/ui
```

## Migration from Old Deployment

If you're migrating from the old standalone deployment:

1. Verify the new kgateway deployment is working
2. Run the cleanup script:
   ```bash
   chmod +x cleanup-old.sh
   ./cleanup-old.sh
   ```
3. Update DNS if needed for the UI subdomain

## Additional Resources

- [Official kgateway documentation](https://kgateway.dev/docs/agentgateway/)
- [Gateway API specification](https://gateway-api.sigs.k8s.io/)
- [Detailed deployment guide](../docs/kubernetes-deployment.md)