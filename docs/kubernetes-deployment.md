# AgentGateway Kubernetes Deployment Guide

This guide covers deploying AgentGateway to Kubernetes using the **official kgateway control plane** with Gateway API, Docker Hub registry, SSL certificates via Let's Encrypt, and automated CI/CD.

> **Note**: This deployment uses the kgateway control plane, which is the recommended standard for Kubernetes deployments. For local development, see the [local deployment docs](https://agentgateway.dev/docs/local/).

## Table of Contents

1. [Deployment Overview](#deployment-overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [GitHub Secrets Configuration](#github-secrets-configuration)
5. [Manual Deployment](#manual-deployment)
6. [Automated Deployment](#automated-deployment)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance](#maintenance)
10. [Migration from Old Deployment](#migration-from-old-deployment)

## Deployment Overview

### Architecture

This deployment uses the **kgateway control plane**, which provides:
- Automatic proxy lifecycle management
- Gateway API-based declarative configuration
- Validated configuration at apply-time
- Standards-compliant Kubernetes integration

```
┌──────────────────────────────────────┐
│    kgateway Control Plane            │
│  (Manages agentgateway proxies)      │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│     Gateway API Resources            │
│  - Gateway                           │
│  - HTTPRoute                         │
│  - AgentgatewayParameters            │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│   agentgateway Proxy Pods            │
│  (Auto-provisioned)                  │
└─────┬──────────────────────┬─────────┘
      │                      │
      ▼                      ▼
┌─────────────┐      ┌──────────────┐
│ API Traffic │      │  UI Access   │
│ Port 3000   │      │  Port 15000  │
└─────────────┘      └──────────────┘
```

### Key Components

- **kgateway Control Plane**: Manages proxy lifecycle via Helm chart
- **Gateway**: Entry point for traffic, references configuration
- **HTTPRoute**: Routing rules for API traffic
- **AgentgatewayParameters**: Configuration CRD for proxy settings
- **UI Service**: Separate service for UI access on subdomain
- **Ingresses**: SSL-enabled ingresses for both API and UI

### Access Points

- **API**: `https://agentgateway.prometheusags.ai`
- **UI**: `https://ui.agentgateway.prometheusags.ai/ui`
- **Health**: `https://agentgateway.prometheusags.ai/health`

## Prerequisites

### Required Tools
- `kubectl` configured for your GKE cluster
- Docker Hub account
- GKE cluster with nginx-ingress controller installed
- cert-manager installed in the cluster
- DNS configured to point `agentgateway.prometheusags.ai` to your cluster's load balancer

### Required Permissions
- Docker Hub: Push access to repository
- GKE: Kubernetes admin access
- GitHub: Repository admin access for secrets configuration

## Initial Setup

### 1. Docker Hub Configuration

The build system has been modified to use Docker Hub instead of GitHub Container Registry:

```makefile
# Makefile changes
DOCKER_REGISTRY ?= docker.io
DOCKER_REPO ?= tribehealth
```

Images will be pushed to: `docker.io/tribehealth/agentgateway:*`

### 2. Kubernetes Cluster Requirements

Your GKE cluster must have:
- **nginx-ingress controller**: For SSL termination and routing
- **cert-manager**: For automatic SSL certificate management
- **Helm 3**: For installing kgateway control plane
- **DNS configuration**: 
  - `agentgateway.prometheusags.ai` → Load balancer IP (API)
  - `ui.agentgateway.prometheusags.ai` → Load balancer IP (UI)

## GitHub Secrets Configuration

Configure these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

### Required Secrets

| Secret Name | Description | Example |
|------------|-------------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub username | `tribehealth` |
| `DOCKERHUB_TOKEN` | Docker Hub access token | `dckr_pat_abc123...` |
| `GKE_PROJECT` | Google Cloud Project ID | `my-project-123` |
| `KUBE_CONFIG_DATA` | Base64 encoded kubeconfig | `apiVersion: v1...` (base64) |

### Optional Secrets

| Secret Name | Description | Notes |
|------------|-------------|-------|
| `GKE_CLUSTER` | Cluster name | Only if using gcloud auth |
| `GKE_ZONE` | Cluster zone | Only if using gcloud auth |

### Creating kubeconfig secret

```bash
# Get your kubeconfig and encode it
kubectl config view --raw --flatten | base64 -w 0
# Copy the output to KUBE_CONFIG_DATA secret
```

## Manual Deployment

### 1. Install Gateway API CRDs

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
```

### 2. Create namespace and secrets

```bash
# Create namespace for kgateway system
kubectl create namespace agentgateway-system

# Create OpenAI API key secret
kubectl create secret generic agentgateway-secrets \
  --from-literal=openai-api-key=YOUR_OPENAI_API_KEY \
  --namespace=agentgateway-system
```

### 3. Install kgateway control plane

```bash
# Install kgateway CRDs
helm upgrade -i agentgateway-crds oci://ghcr.io/kgateway-dev/charts/agentgateway-crds \
  --namespace agentgateway-system \
  --version v2.2.0-main \
  --wait

# Install kgateway control plane
helm upgrade -i agentgateway oci://ghcr.io/kgateway-dev/charts/agentgateway \
  --namespace agentgateway-system \
  --version v2.2.0-main \
  --values k8s/kgateway-values.yaml \
  --wait
```

### 4. Deploy AgentGateway configuration

```bash
# Apply SSL cluster issuer
kubectl apply -f k8s/cluster-issuer.yaml

# Apply AgentGateway configuration
kubectl apply -f k8s/agentgateway-params.yaml

# Apply Gateway and routing
kubectl apply -f k8s/gateway.yaml
kubectl apply -f k8s/httproute.yaml

# Apply UI service and ingress
kubectl apply -f k8s/ui-service.yaml
kubectl apply -f k8s/ui-ingress.yaml
```

### 5. Wait for Gateway to be ready

```bash
kubectl wait --for=condition=Programmed gateway/agentgateway -n agentgateway-system --timeout=300s
```

## Automated Deployment

### Workflow Overview

The GitHub Actions workflow (`.github/workflows/deploy.yml`) automatically:

1. **UI Build**: Builds the Next.js UI with Node.js 23
2. **Multi-arch Docker Build**: Builds for `linux/amd64` and `linux/arm64`
3. **Docker Hub Push**: Creates manifest list and pushes to Docker Hub
4. **Image Signing**: Signs container images with cosign
5. **GKE Deployment**: Updates Kubernetes deployment with new image
6. **Health Verification**: Performs health checks

### Trigger Conditions

- **Automatic**: Push to `main` branch
- **Manual**: Workflow dispatch from GitHub UI

### Deployment Strategy

- **Rolling Update**: Zero-downtime deployment with `maxSurge: 1, maxUnavailable: 0`
- **Health Checks**: Readiness and liveness probes ensure stability
- **Rollback**: Automatic rollback if deployment fails

## Verification

### 1. Check Deployment Status

```bash
# Check all resources
kubectl get all -n agentgateway

# Check pod status
kubectl get pods -n agentgateway -l app=agentgateway

# Check service
kubectl get svc -n agentgateway

# Check ingress
kubectl get ingress -n agentgateway
```

### 2. Certificate Status

```bash
# Check certificate
kubectl get certificate -n agentgateway

# Check certificate details
kubectl describe certificate agentgateway-tls -n agentgateway
```

### 3. Health Check

```bash
# Local health check via port-forward
kubectl port-forward svc/agentgateway-service 8080:80 -n agentgateway
curl http://localhost:8080/health

# External health check (once DNS is configured)
curl https://agentgateway.prometheusags.ai/health
```

### 4. View Logs

```bash
# View current logs
kubectl logs -f deployment/agentgateway -n agentgateway

# View logs from all pods
kubectl logs -l app=agentgateway -n agentgateway --all-containers=true
```

## Troubleshooting

### Common Issues

#### 1. Pod CrashLoopBackOff

```bash
# Check pod details
kubectl describe pods -l app=agentgateway -n agentgateway

# Check logs
kubectl logs -l app=agentgateway -n agentgateway --previous
```

**Common causes**:
- Missing OpenAI API key secret
- Configuration file syntax errors
- Resource limits too low

#### 2. Ingress Not Working

```bash
# Check ingress details
kubectl describe ingress agentgateway-ingress -n agentgateway

# Check nginx ingress controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

**Common causes**:
- DNS not pointing to load balancer IP
- cert-manager not installed
- Ingress class misconfiguration

#### 3. SSL Certificate Issues

```bash
# Check certificate status
kubectl describe certificate agentgateway-tls -n agentgateway

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

**Common causes**:
- DNS validation failing
- Rate limiting from Let's Encrypt
- Incorrect email in ClusterIssuer

#### 4. Docker Registry Issues

```bash
# Check if image exists
docker pull docker.io/tribehealth/agentgateway:latest

# Check GitHub Actions logs
# Go to GitHub → Actions → Failed workflow → View logs
```

**Common causes**:
- Incorrect Docker Hub credentials
- Registry permissions
- Network issues during build

### Debug Commands

```bash
# Get comprehensive cluster state
kubectl get all,configmaps,secrets,ingress,certificates -n agentgateway

# Check events
kubectl get events -n agentgateway --sort-by=.metadata.creationTimestamp

# Test internal connectivity
kubectl run debug --image=nicolaka/netshoot -it --rm -- /bin/bash
# Inside the pod:
# nslookup agentgateway-service.agentgateway.svc.cluster.local
# curl http://agentgateway-service.agentgateway.svc.cluster.local/health
```

## Maintenance

### Updating the Application

Deployment updates happen automatically on pushes to main branch. For manual updates:

```bash
# Update with specific image tag
kubectl set image deployment/agentgateway agentgateway=docker.io/tribehealth/agentgateway:NEW_TAG -n agentgateway

# Watch rollout
kubectl rollout status deployment/agentgateway -n agentgateway
```

### Configuration Updates

```bash
# Edit configmap
kubectl edit configmap agentgateway-config -n agentgateway

# Restart deployment to pick up changes
kubectl rollout restart deployment/agentgateway -n agentgateway
```

### Scaling

```bash
# Scale deployment
kubectl scale deployment agentgateway --replicas=3 -n agentgateway

# Or edit the deployment
kubectl edit deployment agentgateway -n agentgateway
```

### Certificate Renewal

Certificates auto-renew via cert-manager. To force renewal:

```bash
# Delete certificate to trigger renewal
kubectl delete certificate agentgateway-tls -n agentgateway

# cert-manager will automatically recreate it
```

### Monitoring

Set up monitoring with Prometheus:

```bash
# The deployment includes Prometheus annotations
# prometheus.io/scrape: "true"
# prometheus.io/port: "3000"
# prometheus.io/path: "/metrics"
```

### Backup and Recovery

```bash
# Backup configuration
kubectl get configmap agentgateway-config -n agentgateway -o yaml > backup-configmap.yaml
kubectl get secret agentgateway-secrets -n agentgateway -o yaml > backup-secrets.yaml

# Restore configuration
kubectl apply -f backup-configmap.yaml
kubectl apply -f backup-secrets.yaml
```

## Security Considerations

### Container Security
- Uses Chainguard base images for minimal attack surface
- Runs as non-root user (UID 65534)
- Read-only root filesystem
- Drops all capabilities

### Kubernetes Security
- Pod Security Standards enforced
- Network policies can be added for network segmentation
- Resource limits prevent resource exhaustion
- Secrets mounted securely

### SSL/TLS
- Automatic certificate management with Let's Encrypt
- TLS 1.2+ enforced
- HSTS headers recommended

## Performance Tuning

### Resource Allocation
```yaml
resources:
  requests:
    memory: "128Mi"  # Increase for high load
    cpu: "100m"      # Increase for high load
  limits:
    memory: "512Mi"  # Increase if seeing OOMKilled
    cpu: "500m"      # Increase for CPU-intensive workloads
```

### Horizontal Pod Autoscaling
```bash
# Create HPA
kubectl autoscale deployment agentgateway --cpu-percent=70 --min=2 --max=10 -n agentgateway
```

## Success Criteria

✅ **Build Pipeline**
- AgentGateway builds successfully with UI
- Multi-arch Docker images push to Docker Hub
- Images are signed with cosign

✅ **kgateway Control Plane**
- kgateway controller running in `agentgateway-system` namespace
- Gateway API CRDs installed
- AgentgatewayParameters CRD applied successfully

✅ **Gateway and Proxy**
- Gateway resource shows `Programmed` condition
- agentgateway proxy pods running healthy
- HTTPRoute attached to Gateway
- Services auto-created by Gateway API

✅ **SSL and Ingress**
- HTTPS accessible via `agentgateway.prometheusags.ai` (API)
- HTTPS accessible via `ui.agentgateway.prometheusags.ai` (UI)
- SSL certificates automatically issued and renewed for both domains
- CORS headers properly configured

✅ **CI/CD Pipeline**
- Automatic deployment on main branch commits
- kgateway Helm chart installation successful
- Zero-downtime rolling updates
- Health checks pass for both API and UI

✅ **Monitoring and Observability**
- Logs accessible via kubectl for proxy pods
- Health endpoint responding at `/health`
- UI accessible at `/ui` on UI subdomain
- Prometheus metrics available on port 15020

## Migration from Old Deployment

If you're migrating from the old standalone deployment (using `deployment.yaml`, `configmap.yaml`, etc.) to the new kgateway-based approach:

### Pre-Migration Checklist

1. **Backup current configuration**:
   ```bash
   kubectl get configmap agentgateway-config -n agentgateway -o yaml > backup-configmap.yaml
   kubectl get secret agentgateway-secrets -n agentgateway -o yaml > backup-secrets.yaml
   kubectl get deployment agentgateway -n agentgateway -o yaml > backup-deployment.yaml
   ```

2. **Note current settings**:
   - OpenAI API key location
   - Custom configuration values
   - Resource limits
   - Any custom environment variables

### Migration Steps

1. **Deploy new kgateway-based system** (follow Manual Deployment steps above)

2. **Verify new deployment is working**:
   ```bash
   # Check Gateway status
   kubectl get gateway -n agentgateway-system
   
   # Check proxy pods
   kubectl get pods -n agentgateway-system -l gateway.networking.k8s.io/gateway-name=agentgateway
   
   # Test API endpoint
   curl https://agentgateway.prometheusags.ai/health
   
   # Test UI endpoint
   curl https://ui.agentgateway.prometheusags.ai/ui
   ```

3. **Update DNS for UI subdomain**:
   - Add DNS A/CNAME record: `ui.agentgateway.prometheusags.ai` → Load balancer IP
   - Wait for DNS propagation

4. **Run cleanup script**:
   ```bash
   cd k8s
   chmod +x cleanup-old.sh
   ./cleanup-old.sh
   ```

5. **Verify cleanup**:
   ```bash
   # Old namespace should be empty or can be deleted
   kubectl get all -n agentgateway
   
   # New namespace should have all resources
   kubectl get all,gateway,httproute -n agentgateway-system
   ```

### Rollback Plan

If you need to rollback to the old deployment:

1. The old manifests are preserved with deprecation notices
2. Restore from backups:
   ```bash
   kubectl apply -f backup-configmap.yaml
   kubectl apply -f backup-deployment.yaml
   kubectl apply -f k8s/service.yaml
   kubectl apply -f k8s/ingress.yaml
   ```

3. Delete new deployment:
   ```bash
   helm uninstall agentgateway agentgateway-crds -n agentgateway-system
   kubectl delete namespace agentgateway-system
   ```

### Key Differences

| Aspect | Old Deployment | New kgateway Deployment |
|--------|---------------|------------------------|
| **Namespace** | `agentgateway` | `agentgateway-system` |
| **Configuration** | ConfigMap | AgentgatewayParameters CRD |
| **Deployment** | Manual manifests | Gateway API + Helm |
| **UI Access** | Path-based (`/ui`) | Subdomain (`ui.agentgateway.prometheusags.ai`) |
| **Admin Binding** | `0.0.0.0:15000` | `127.0.0.1:15000` (accessed via service) |
| **Management** | Manual updates | kgateway control plane |
| **Validation** | Runtime errors | Apply-time validation |

## Support

For issues with this deployment:

1. Check the troubleshooting section above
2. Review GitHub Actions logs for build issues
3. Use `kubectl describe` and `kubectl logs` for runtime issues
4. Check cert-manager and ingress controller logs for SSL/routing issues
5. For kgateway-specific issues, check [kgateway documentation](https://kgateway.dev/docs/)

Remember to always test changes in a staging environment before deploying to production.