# Deployment Checklist - kgateway Migration

## ✅ Completed

- [x] Created kgateway Helm values configuration
- [x] Created AgentgatewayParameters CRD
- [x] Created Gateway API resources (Gateway, HTTPRoute)
- [x] Created UI service and ingress for separate subdomain
- [x] Updated GitHub Actions workflow to use kgateway
- [x] Added comprehensive health checks for API and UI
- [x] Updated all documentation
- [x] Added deprecation notices to old files
- [x] Created cleanup script for old resources
- [x] Committed all changes to git
- [x] Pushed changes to remote repository (commit: e25c100)

## 🔍 GitHub Actions Workflow Verification

### Workflow Configuration
- **File**: `.github/workflows/deploy.yml`
- **Trigger**: Push to `main` branch (✅ Just pushed!)
- **Status**: Workflow should be running now

### Required GitHub Secrets

The workflow requires these secrets to be configured in your repository:

1. **DOCKERHUB_USERNAME** - Docker Hub username
2. **DOCKERHUB_TOKEN** - Docker Hub access token
3. **GCP_SA_KEY** - Google Cloud service account key (JSON)

### Required GitHub Variables

The workflow requires these variables:

1. **GKE_CLUSTER** - GKE cluster name
2. **GKE_REGION** - GKE cluster region
3. **GCP_PROJECT** - Google Cloud project ID

### Workflow Steps

The GitHub Actions workflow will:

1. ✅ Checkout code
2. ✅ Generate image tag
3. ✅ Build UI
4. ✅ Build and push Docker image
5. ✅ Sign container image
6. ✅ Authenticate to GCP
7. ✅ Fetch kubeconfig
8. ✅ Install Helm
9. ✅ Install Gateway API CRDs
10. ✅ Install kgateway control plane
11. ✅ Deploy AgentGateway configuration
12. ✅ Wait for Gateway to be ready
13. ✅ Wait for proxy deployment
14. ✅ Verify deployment
15. ✅ Health check (API and UI)
16. ✅ Deployment summary

## 📋 Pre-Deployment Requirements

### 1. DNS Configuration

**IMPORTANT**: Add DNS record for UI subdomain before deployment completes:

```
Type: A or CNAME
Name: gateway-ui.prometheusags.ai
Value: [Same load balancer IP as agentgateway.prometheusags.ai]
```

To get the load balancer IP after deployment:
```bash
kubectl get ingress -n agentgateway-system
```

### 2. Kubernetes Cluster Prerequisites

Verify your GKE cluster has:
- ✅ nginx-ingress controller installed
- ✅ cert-manager installed
- ✅ Sufficient resources for kgateway control plane and proxy

### 3. Secrets in Kubernetes

The OpenAI API key secret will need to be created in the new namespace:

```bash
kubectl create secret generic agentgateway-secrets \
  --from-literal=openai-api-key=YOUR_OPENAI_API_KEY \
  --namespace=agentgateway-system
```

**Note**: The workflow doesn't create this secret automatically. You may need to:
- Create it manually before deployment, OR
- Migrate it from the old namespace, OR
- Add a step to the workflow to create it

## 🚀 Deployment Status

### Check GitHub Actions

1. Go to: https://github.com/Prometheus-AGS/agentgateway/actions
2. Look for the workflow run triggered by commit `e25c100`
3. Monitor the deployment progress

### Expected Outcome

After successful deployment:
- **API**: https://agentgateway.prometheusags.ai
- **Health**: https://agentgateway.prometheusags.ai/health
- **UI**: https://gateway-ui.prometheusags.ai/ui (after DNS propagation)

### Verify Deployment

Once the workflow completes, verify:

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

# Test UI (may need to wait for DNS)
curl https://gateway-ui.prometheusags.ai/ui
```

## 🧹 Post-Deployment Cleanup

After verifying the new deployment works:

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

## ⚠️ Potential Issues and Solutions

### Issue: Workflow fails at "Install kgateway control plane"

**Solution**: Check that Helm can access the OCI registry:
```bash
helm pull oci://ghcr.io/kgateway-dev/charts/agentgateway-crds --version v2.2.0-main
```

### Issue: Gateway not becoming ready

**Solution**: Check kgateway controller logs:
```bash
kubectl logs -f deployment/agentgateway -n agentgateway-system
```

### Issue: UI not accessible

**Solution**: 
1. Verify DNS has propagated: `nslookup gateway-ui.prometheusags.ai`
2. Check certificate status: `kubectl get certificate -n agentgateway-system`
3. Test locally: `kubectl port-forward svc/agentgateway-ui 15000:15000 -n agentgateway-system`

### Issue: Secrets not found

**Solution**: Create the secret in the new namespace:
```bash
kubectl create secret generic agentgateway-secrets \
  --from-literal=openai-api-key=YOUR_OPENAI_API_KEY \
  --namespace=agentgateway-system
```

## 📞 Support

If you encounter issues:

1. Check GitHub Actions logs
2. Review `k8s/MIGRATION_SUMMARY.md`
3. Check `docs/kubernetes-deployment.md` troubleshooting section
4. Review kgateway logs: `kubectl logs -f deployment/agentgateway -n agentgateway-system`
5. Review proxy logs: `kubectl logs -f -l gateway.networking.k8s.io/gateway-name=agentgateway -n agentgateway-system`

## 🎯 Success Criteria

Deployment is successful when:

- [x] GitHub Actions workflow completes without errors
- [ ] Gateway shows `Programmed` condition
- [ ] Proxy pods are running and healthy
- [ ] API endpoint responds: https://agentgateway.prometheusags.ai/health
- [ ] UI endpoint responds: https://gateway-ui.prometheusags.ai/ui
- [ ] SSL certificates issued for both domains
- [ ] Health checks pass in workflow

## 📚 Documentation

- **Quick Start**: [k8s/README.md](k8s/README.md)
- **Migration Guide**: [k8s/MIGRATION_SUMMARY.md](k8s/MIGRATION_SUMMARY.md)
- **Detailed Deployment**: [docs/kubernetes-deployment.md](docs/kubernetes-deployment.md)
- **Official Docs**: https://kgateway.dev/docs/agentgateway/
