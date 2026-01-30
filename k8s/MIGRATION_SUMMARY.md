# Migration to kgateway Standard Deployment - Summary

## Overview

Your AgentGateway deployment has been migrated from a custom standalone approach to the **official kgateway control plane** method, which is the recommended standard for Kubernetes deployments.

## What Changed

### Architecture

**Before (Non-Standard):**
- Manual Kubernetes manifests (deployment.yaml, configmap.yaml, service.yaml)
- Single ingress for both API and UI using path-based routing (`/ui`)
- Admin interface bound to `0.0.0.0:15000` for external access
- Direct ConfigMap with CEL expressions

**After (Standard kgateway):**
- kgateway control plane managing proxy lifecycle
- Gateway API resources (Gateway, HTTPRoute)
- AgentgatewayParameters CRD for validated configuration
- Separate UI service and ingress on subdomain (`gateway-ui.prometheusags.ai`)
- Admin interface on `127.0.0.1:15000` (accessed via dedicated service)

### New Files Created

1. **k8s/kgateway-values.yaml** - Helm values for kgateway control plane
2. **k8s/agentgateway-params.yaml** - AgentgatewayParameters CRD configuration
3. **k8s/gateway.yaml** - Gateway API Gateway resource
4. **k8s/httproute.yaml** - Gateway API HTTPRoute for API traffic
5. **k8s/ui-service.yaml** - Dedicated service for UI access
6. **k8s/ui-ingress.yaml** - Separate ingress for UI subdomain
7. **k8s/cleanup-old.sh** - Script to remove old deployment resources
8. **k8s/MIGRATION_SUMMARY.md** - This file

### Files Modified

1. **.github/workflows/deploy.yml** - Updated to use kgateway deployment
2. **k8s/README.md** - Documented new kgateway-based approach
3. **docs/kubernetes-deployment.md** - Updated with kgateway deployment guide

### Files Deprecated (Kept for Reference)

1. **k8s/deployment.yaml** - Marked as deprecated
2. **k8s/configmap.yaml** - Marked as deprecated
3. **k8s/service.yaml** - Marked as deprecated
4. **k8s/ingress.yaml** - Marked as deprecated

## Access Points

After deployment, you'll have:

- **API**: https://agentgateway.prometheusags.ai
- **Health**: https://agentgateway.prometheusags.ai/health
- **UI**: https://gateway-ui.prometheusags.ai/ui

## Deployment Flow

The GitHub Actions workflow now:

1. Builds and pushes Docker image (unchanged)
2. Installs Gateway API CRDs
3. Installs kgateway control plane via Helm
4. Applies AgentgatewayParameters configuration
5. Creates Gateway and HTTPRoute resources
6. Deploys UI service and ingress
7. Performs health checks on both API and UI endpoints

## Next Steps

### 1. Update DNS Configuration

Add a DNS record for the UI subdomain:
- **Record**: `gateway-ui.prometheusags.ai`
- **Type**: A or CNAME
- **Value**: Same load balancer IP as `agentgateway.prometheusags.ai`

### 2. Deploy the New Configuration

The GitHub Actions workflow will automatically deploy on the next push to main. Or deploy manually:

```bash
# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

# Create namespace
kubectl create namespace agentgateway-system

# Install kgateway
helm upgrade -i agentgateway-crds oci://ghcr.io/kgateway-dev/charts/agentgateway-crds \
  --namespace agentgateway-system \
  --version v2.2.0-main \
  --wait

helm upgrade -i agentgateway oci://ghcr.io/kgateway-dev/charts/agentgateway \
  --namespace agentgateway-system \
  --version v2.2.0-main \
  --values k8s/kgateway-values.yaml \
  --wait

# Apply configuration
kubectl apply -f k8s/cluster-issuer.yaml
kubectl apply -f k8s/agentgateway-params.yaml
kubectl apply -f k8s/gateway.yaml
kubectl apply -f k8s/httproute.yaml
kubectl apply -f k8s/ui-service.yaml
kubectl apply -f k8s/ui-ingress.yaml
```

### 3. Verify Deployment

```bash
# Check Gateway status
kubectl get gateway -n agentgateway-system

# Check proxy pods
kubectl get pods -n agentgateway-system -l gateway.networking.k8s.io/gateway-name=agentgateway

# Check services
kubectl get svc -n agentgateway-system

# Check ingresses
kubectl get ingress -n agentgateway-system

# Test API
curl https://agentgateway.prometheusags.ai/health

# Test UI (after DNS propagation)
curl https://gateway-ui.prometheusags.ai/ui
```

### 4. Clean Up Old Deployment (After Verification)

Once the new deployment is working:

```bash
cd k8s
chmod +x cleanup-old.sh
./cleanup-old.sh
```

This will remove:
- Old deployment in `agentgateway` namespace
- Old service
- Old configmap
- Old ingress
- Old certificates

It will preserve:
- Secrets (can be migrated if needed)
- ClusterIssuer (shared resource)

## Benefits of New Approach

1. **Standards Compliance**: Uses official kgateway control plane
2. **Better Security**: UI on separate subdomain with isolated ingress
3. **Easier Management**: Gateway API provides declarative configuration
4. **Validation**: AgentgatewayParameters validates config at apply-time
5. **Scalability**: kgateway handles proxy lifecycle automatically
6. **Future-Proof**: Follows Kubernetes Gateway API standard

## Troubleshooting

### Gateway not ready

```bash
kubectl describe gateway agentgateway -n agentgateway-system
kubectl logs -f deployment/agentgateway -n agentgateway-system
```

### Proxy pods not starting

```bash
kubectl get pods -n agentgateway-system -l gateway.networking.k8s.io/gateway-name=agentgateway
kubectl logs -f -l gateway.networking.k8s.io/gateway-name=agentgateway -n agentgateway-system
```

### UI not accessible

```bash
# Check service
kubectl get svc agentgateway-ui -n agentgateway-system

# Check ingress
kubectl describe ingress agentgateway-ui-ingress -n agentgateway-system

# Check certificate
kubectl get certificate -n agentgateway-system

# Port-forward for local testing
kubectl port-forward svc/agentgateway-ui 15000:15000 -n agentgateway-system
# Then access: http://localhost:15000/ui
```

### DNS not resolving

```bash
# Check DNS propagation
nslookup gateway-ui.prometheusags.ai

# Check ingress external IP
kubectl get ingress -n agentgateway-system
```

## Rollback Plan

If you need to rollback to the old deployment:

1. The old manifests are preserved with deprecation notices
2. Delete new deployment:
   ```bash
   helm uninstall agentgateway agentgateway-crds -n agentgateway-system
   kubectl delete namespace agentgateway-system
   ```
3. Restore old deployment:
   ```bash
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/deployment.yaml
   kubectl apply -f k8s/service.yaml
   kubectl apply -f k8s/ingress.yaml
   ```

## Documentation

- **Quick Start**: [k8s/README.md](README.md)
- **Detailed Guide**: [docs/kubernetes-deployment.md](../docs/kubernetes-deployment.md)
- **Official kgateway Docs**: https://kgateway.dev/docs/agentgateway/
- **Gateway API Docs**: https://gateway-api.sigs.k8s.io/

## Support

For issues:
1. Check the troubleshooting sections in documentation
2. Review GitHub Actions logs for deployment issues
3. Check kgateway controller logs: `kubectl logs -f deployment/agentgateway -n agentgateway-system`
4. Check proxy logs: `kubectl logs -f -l gateway.networking.k8s.io/gateway-name=agentgateway -n agentgateway-system`
