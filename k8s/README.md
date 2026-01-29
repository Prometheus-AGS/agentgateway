# AgentGateway Kubernetes Deployment

Quick deployment guide for AgentGateway on Kubernetes with Docker Hub and Let's Encrypt SSL.

## Quick Start

1. **Set up secrets** (replace with your actual values):
   ```bash
   kubectl create secret generic agentgateway-secrets \
     --from-literal=openai-api-key=YOUR_OPENAI_API_KEY \
     --namespace=agentgateway
   ```

2. **Deploy everything**:
   ```bash
   ./deploy.sh
   ```

3. **Check status**:
   ```bash
   kubectl get all -n agentgateway
   ```

4. **View logs**:
   ```bash
   kubectl logs -f deployment/agentgateway -n agentgateway
   ```

## Files Overview

| File | Purpose |
|------|---------|
| `namespace.yaml` | Creates the agentgateway namespace |
| `configmap.yaml` | AgentGateway configuration with AI backend |
| `deployment.yaml` | 2-replica deployment with health checks |
| `service.yaml` | ClusterIP service exposing port 80 |
| `cluster-issuer.yaml` | Let's Encrypt certificate issuer |
| `ingress.yaml` | Nginx ingress with SSL and CORS |
| `secrets-template.yaml` | Template for creating secrets |
| `deploy.sh` | Deployment script |

## Configuration

The ConfigMap includes:
- **Port 3000**: Main application port
- **Health endpoint**: `/health` for readiness/liveness probes
- **AI Backend**: OpenAI GPT-4o-mini (requires API key)
- **CORS**: Configured for web access

## SSL Certificate

SSL is automatically managed by cert-manager with Let's Encrypt:
- **Domain**: `agentgateway.prometheusags.ai`
- **Challenge**: HTTP-01
- **Renewal**: Automatic

## GitHub Actions

The deployment workflow (`.github/workflows/deploy.yml`) automatically:
- Builds multi-arch Docker images
- Pushes to Docker Hub (`docker.io/tribehealth/agentgateway`)
- Deploys to GKE on pushes to main branch

Required GitHub secrets:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `KUBE_CONFIG_DATA` (base64 encoded kubeconfig)

## Health Checks

- **Readiness**: `GET /health` (port 3000)
- **Liveness**: `GET /health` (port 3000)
- **External**: `https://agentgateway.prometheusags.ai/health`

## Troubleshooting

```bash
# Check pod status
kubectl get pods -n agentgateway

# View events
kubectl get events -n agentgateway --sort-by=.metadata.creationTimestamp

# Check certificate
kubectl describe certificate agentgateway-tls -n agentgateway

# Port forward for local testing
kubectl port-forward svc/agentgateway-service 8080:80 -n agentgateway
curl http://localhost:8080/health
```

See [docs/kubernetes-deployment.md](../docs/kubernetes-deployment.md) for detailed documentation.