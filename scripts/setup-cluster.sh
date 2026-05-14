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
  petclinic-observability-lead \
  petclinic-observability-engineer; do

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

# Grant EKS access to GitHub Actions role
echo "Granting EKS access to GitHub Actions role..."
aws eks create-access-entry \
  --cluster-name petclinic-cluster \
  --principal-arn arn:aws:iam::045810265680:role/github-actions-petclinic \
  --region us-east-1 2>/dev/null || true

aws eks associate-access-policy \
  --cluster-name petclinic-cluster \
  --principal-arn arn:aws:iam::045810265680:role/github-actions-petclinic \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-1 2>/dev/null || true
echo "✅ GitHub Actions role granted EKS access"

# Recreate GitHub Actions OIDC provider and role if missing
echo "Ensuring GitHub Actions OIDC provider exists..."
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 2>/dev/null || true

cat > /tmp/github-oidc-trust.json << 'TRUSTEOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::045810265680:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:PETCLINIC-PROJECT-GROUP-5/spring-petclinic-microservices:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
TRUSTEOF

aws iam create-role \
  --role-name github-actions-petclinic \
  --assume-role-policy-document file:///tmp/github-oidc-trust.json 2>/dev/null || \
aws iam update-assume-role-policy \
  --role-name github-actions-petclinic \
  --policy-document file:///tmp/github-oidc-trust.json

aws iam attach-role-policy \
  --role-name github-actions-petclinic \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess 2>/dev/null || true

aws iam attach-role-policy \
  --role-name github-actions-petclinic \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy 2>/dev/null || true
echo "✅ GitHub Actions role ready"
# Update EBS CSI role trust policy with current cluster OIDC ID
echo "Updating EBS CSI trust policy..."
OIDC_ID=$(aws eks describe-cluster \
  --name petclinic-cluster \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text | cut -d '/' -f 5)

cat > /tmp/ebs-csi-trust.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::045810265680:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com",
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF

aws iam update-assume-role-policy \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --policy-document file:///tmp/ebs-csi-trust.json
echo "✅ EBS CSI trust policy updated for OIDC ID: $OIDC_ID"

# Install EBS CSI driver
echo "Installing EBS CSI driver..."
aws eks create-addon \
  --cluster-name petclinic-cluster \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::045810265680:role/AmazonEKS_EBS_CSI_DriverRole \
  --region us-east-1 2>/dev/null || true

echo "Waiting for EBS CSI driver to be ACTIVE..."
for i in $(seq 1 20); do
  STATUS=$(aws eks describe-addon \
    --cluster-name petclinic-cluster \
    --addon-name aws-ebs-csi-driver \
    --region us-east-1 \
    --query 'addon.status' \
    --output text)
  echo "  Status: $STATUS (attempt $i/20)"
  if [ "$STATUS" = "ACTIVE" ]; then
    break
  fi
  sleep 30
done
echo "✅ EBS CSI driver ready"

# Install Metrics Server
echo "Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
echo "Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=Available deployment/metrics-server \
  -n kube-system \
  --timeout=120s
echo "✅ Metrics Server ready"

# Update LBC role trust policy with current OIDC ID
echo "Updating LBC trust policy..."
OIDC_ID=$(aws eks describe-cluster \
  --name petclinic-cluster \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text | cut -d '/' -f 5)

cat > /tmp/lbc-trust.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::045810265680:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com",
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
EOF

aws iam update-assume-role-policy \
  --role-name AmazonEKS_LBC_Role \
  --policy-document file:///tmp/lbc-trust.json
echo "✅ LBC trust policy updated for OIDC ID: $OIDC_ID"

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

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=petclinic-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::045810265680:role/AmazonEKS_LBC_Role \
  --set region=us-east-1 \
  --set vpcId=$VPC_ID

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
