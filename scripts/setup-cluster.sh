#!/bin/bash
set -e

echo "Setting up EKS cluster post-provisioning..."

export AWS_PROFILE=dmi-group5

# Update kubeconfig
aws eks update-kubeconfig \
  --region us-east-1 \
  --name petclinic-cluster \
  --profile dmi-group5

# Grant IAM access
aws eks create-access-entry \
  --cluster-name petclinic-cluster \
  --principal-arn arn:aws:iam::045810265680:user/petclinic-infra-lead \
  --region us-east-1 2>/dev/null || true

aws eks associate-access-policy \
  --cluster-name petclinic-cluster \
  --principal-arn arn:aws:iam::045810265680:user/petclinic-infra-lead \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-1 2>/dev/null || true

  # Grant EKS access to all team members
echo "Granting EKS access to team members..."
for user in \
  petclinic-k8s-lead \
  petclinic-k8s-engineer \
  petclinic-cicd-lead \
  petclinic-cicd-engineer \
  petclinic-obs-lead \
  petclinic-obs-engineer; do

  aws eks create-access-entry \
    --cluster-name petclinic-cluster \
    --principal-arn arn:aws:iam::045810265680:user/$user \
    --region us-east-1 2>/dev/null || true

  aws eks associate-access-policy \
    --cluster-name petclinic-cluster \
    --principal-arn arn:aws:iam::045810265680:user/$user \
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope type=cluster \
    --region us-east-1 2>/dev/null || true

  echo "✅ $user granted"
done
echo "✅ Team access complete"

# Install EBS CSI driver
echo "Installing EBS CSI driver..."
aws eks create-addon \
  --cluster-name petclinic-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1 2>/dev/null || true

echo "Waiting for EBS CSI driver to be ACTIVE..."
aws eks wait addon-active \
  --cluster-name petclinic-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1
echo "✅ EBS CSI driver ready"

# Install Metrics Server
echo "Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
echo "Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=Available deployment/metrics-server \
  -n kube-system \
  --timeout=120s
echo "✅ Metrics Server ready"

# Install AWS Load Balancer Controller
echo "Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update

VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=tag:Name,Values=petclinic-vpc \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --profile dmi-group5)

echo "VPC ID: $VPC_ID"

# Install or upgrade the controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=petclinic-cluster \
  --set serviceAccount.create=true \
  --set region=us-east-1 \
  --set vpcId=$VPC_ID

echo "Waiting for Load Balancer Controller to be ready..."
kubectl wait --for=condition=Available deployment/aws-load-balancer-controller \
  -n kube-system \
  --timeout=120s
echo "✅ Load Balancer Controller ready"

# Create namespaces
kubectl apply -f k8s/namespaces/namespaces.yml

# Create MySQL secrets
kubectl create secret generic customers-db-secret \
  --namespace petclinic \
  --from-literal=mysql-root-password=petclinic123 \
  --from-literal=mysql-password=petclinic123 \
  --from-literal=mysql-database=petclinic \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic vets-db-secret \
  --namespace petclinic \
  --from-literal=mysql-root-password=petclinic123 \
  --from-literal=mysql-password=petclinic123 \
  --from-literal=mysql-database=petclinic \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic visits-db-secret \
  --namespace petclinic \
  --from-literal=mysql-root-password=petclinic123 \
  --from-literal=mysql-password=petclinic123 \
  --from-literal=mysql-database=petclinic \
  --dry-run=client -o yaml | kubectl apply -f -

# Create ECR secret
kubectl delete secret ecr-secret -n petclinic --ignore-not-found
kubectl create secret docker-registry ecr-secret \
  --namespace petclinic \
  --docker-server=045810265680.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password \
    --region us-east-1 \
    --profile dmi-group5)

echo "✅ Cluster setup complete"
kubectl get secrets -n petclinic
kubectl get nodes
