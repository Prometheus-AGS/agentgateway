# AgentGateway Kubernetes Deployment Guide

This guide covers deploying AgentGateway to Google Kubernetes Engine (GKE) with Docker Hub registry, SSL certificates via Let's Encrypt, and automated CI/CD.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [GitHub Secrets Configuration](#github-secrets-configuration)
4. [Manual Deployment](#manual-deployment)
5. [Automated Deployment](#automated-deployment)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)

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
- **DNS configuration**: `agentgateway.prometheusags.ai` pointing to your ingress load balancer

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

### 1. Create Secrets

First, create the OpenAI API key secret:

```bash
kubectl create secret generic agentgateway-secrets \
  --from-literal=openai-api-key=YOUR_OPENAI_API_KEY \
  --namespace=agentgateway
```

### 2. Deploy using the script

```bash
# Make the script executable
chmod +x k8s/deploy.sh

# Run deployment
./k8s/deploy.sh
```

### 3. Manual deployment steps

If you prefer manual deployment:

```bash
# Apply in order
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/cluster-issuer.yaml
kubectl apply -f k8s/ingress.yaml
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

✅ **Kubernetes Deployment**
- 2 replicas running healthy
- Service accessible internally
- ConfigMap and Secrets properly mounted

✅ **SSL and Ingress**
- HTTPS accessible via `agentgateway.prometheusags.ai`
- SSL certificate automatically issued and renewed
- CORS headers properly configured

✅ **CI/CD Pipeline**
- Automatic deployment on main branch commits
- Zero-downtime rolling updates
- Health checks pass after deployment

✅ **Monitoring and Observability**
- Logs accessible via kubectl
- Health endpoint responding
- Prometheus metrics available (if monitoring is set up)

## Support

For issues with this deployment:

1. Check the troubleshooting section above
2. Review GitHub Actions logs for build issues
3. Use `kubectl describe` and `kubectl logs` for runtime issues
4. Check cert-manager and ingress controller logs for SSL/routing issues

Remember to always test changes in a staging environment before deploying to production.