#!/bin/bash
set -e

echo "🧹 Cleaning up old standalone AgentGateway deployment..."
echo ""
echo "⚠️  WARNING: This will remove the old standalone deployment."
echo "   Make sure the new kgateway-based deployment is working before proceeding."
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo ""
echo "Removing old resources from 'agentgateway' namespace..."

# Remove old deployment
echo "🗑️  Deleting old deployment..."
kubectl delete deployment agentgateway -n agentgateway --ignore-not-found=true

# Remove old service
echo "🗑️  Deleting old service..."
kubectl delete service agentgateway-service -n agentgateway --ignore-not-found=true

# Remove old configmap
echo "🗑️  Deleting old configmap..."
kubectl delete configmap agentgateway-config -n agentgateway --ignore-not-found=true

# Remove old ingress
echo "🗑️  Deleting old ingress..."
kubectl delete ingress agentgateway-ingress -n agentgateway --ignore-not-found=true

# Remove old certificates
echo "🗑️  Deleting old certificates..."
kubectl delete certificate agentgateway-tls -n agentgateway --ignore-not-found=true

echo ""
echo "✅ Old resources removed successfully!"
echo ""
echo "📝 Note: The following resources were preserved:"
echo "  - Namespace 'agentgateway' (kept for secrets)"
echo "  - Secrets (reused by new deployment)"
echo "  - ClusterIssuer (shared resource)"
echo ""
echo "🔍 Verify the new deployment:"
echo "  kubectl get all -n agentgateway-system"
echo "  kubectl get gateway,httproute -n agentgateway-system"
echo ""
echo "🗑️  To remove the old namespace entirely (after verifying secrets are migrated):"
echo "  kubectl delete namespace agentgateway"
