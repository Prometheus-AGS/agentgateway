# AgentGateway Kubernetes Deployment Fix

## Issues Fixed

### 1. CEL Parsing Error
**Error:** `ERROR: <input>:1:4: Syntax error: extraneous input '.0' expecting <EOF>`

**Root Cause:** The `fields.add` section in logging configuration expects CEL expressions, not plain strings. The value `"1.0.0"` was being parsed as a CEL expression and failing.

**Fix:** Changed logging fields to use CEL string literals:
```yaml
fields:
  add:
    service: '"agentgateway"'
    version: '"1.0.0"'
```

### 2. UI Not Accessible
**Error:** `processing failed: failed to parse request: EOF while parsing a value at line 1 column 0`

**Root Cause:** 
- The UI is served on the admin port (15000), but only port 3000 (proxy) was exposed
- Admin interface was bound to `127.0.0.1:15000` (localhost only), not accessible from outside the pod
- Ingress was routing all traffic to port 80 (proxy), including `/` requests

**Fix:**
1. Added `adminAddr: "0.0.0.0:15000"` to config to bind admin interface to all interfaces
2. Added admin port (15000) to deployment and service
3. Updated ingress to route `/ui` to admin port (15000) and everything else to proxy port (80)

## Deployment Instructions

Apply the updated configurations in order:

```bash
# 1. Update the ConfigMap
kubectl apply -f k8s/configmap.yaml

# 2. Update the Service (adds admin port)
kubectl apply -f k8s/service.yaml

# 3. Update the Ingress (adds /ui routing)
kubectl apply -f k8s/ingress.yaml

# 4. Update the Deployment (adds admin port exposure)
kubectl apply -f k8s/deployment.yaml

# 5. Wait for rollout to complete
kubectl rollout status deployment/agentgateway -n agentgateway

# 6. Verify the deployment
kubectl get pods -n agentgateway
kubectl logs -n agentgateway -l app=agentgateway --tail=50
```

## Access Points

After deployment, you'll have:

- **UI:** https://agentgateway.prometheusags.ai/ui
- **API/Proxy:** https://agentgateway.prometheusags.ai/ (all other paths)
- **Health Check:** https://agentgateway.prometheusags.ai/health

## Architecture

```
Internet
    ↓
NGINX Ingress (agentgateway.prometheusags.ai)
    ↓
    ├─ /ui → Service:15000 → Pod:15000 (Admin/UI)
    └─ /*  → Service:80    → Pod:3000  (Proxy/API)
```

## Verification

1. Check that the pod is running:
```bash
kubectl get pods -n agentgateway
```

2. Check logs for successful startup:
```bash
kubectl logs -n agentgateway -l app=agentgateway | grep "serving UI"
```

You should see:
```
{"level":"info","message":"serving UI at http://localhost:15000/ui"}
```

3. Test the UI:
```bash
curl -k https://agentgateway.prometheusags.ai/ui
```

4. Test the health endpoint:
```bash
curl -k https://agentgateway.prometheusags.ai/health
```

## Troubleshooting

If the UI still doesn't load:

1. Check ingress is routing correctly:
```bash
kubectl describe ingress agentgateway-ingress -n agentgateway
```

2. Check service endpoints:
```bash
kubectl get endpoints agentgateway-service -n agentgateway
```

3. Port-forward directly to test:
```bash
kubectl port-forward -n agentgateway svc/agentgateway-service 15000:15000
```
Then access: http://localhost:15000/ui

4. Check pod logs for errors:
```bash
kubectl logs -n agentgateway -l app=agentgateway --tail=100
```
