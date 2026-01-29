#!/bin/bash
set -e

# AgentGateway Kubernetes Deployment Script

NAMESPACE="agentgateway"

echo "🚀 Deploying AgentGateway to Kubernetes..."

# Create namespace first
echo "📦 Creating namespace..."
kubectl apply -f namespace.yaml

# Create secret (you should do this manually with real API key)
echo "🔑 Creating secrets (template only - update with real keys)..."
echo "⚠️  Please update secrets-template.yaml with your actual API keys before applying"
# kubectl apply -f secrets-template.yaml

# Apply configuration
echo "⚙️  Applying configuration..."
kubectl apply -f configmap.yaml

# Deploy application
echo "🚀 Deploying application..."
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Setup SSL and ingress
echo "🔐 Setting up SSL and ingress..."
kubectl apply -f cluster-issuer.yaml
kubectl apply -f ingress.yaml

echo "✅ Deployment initiated!"
echo ""
echo "📊 Checking deployment status..."
kubectl get pods -n $NAMESPACE
echo ""
echo "🌐 Checking service status..."
kubectl get svc -n $NAMESPACE
echo ""
echo "🔗 Checking ingress status..."
kubectl get ingress -n $NAMESPACE
echo ""
echo "🎯 To check if everything is running:"
echo "   kubectl get all -n $NAMESPACE"
echo ""
echo "🔍 To view logs:"
echo "   kubectl logs -f deployment/agentgateway -n $NAMESPACE"
echo ""
echo "🌍 Once DNS is configured, the service will be available at:"
echo "   https://agentgateway.prometheusags.ai"