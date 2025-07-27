#!/bin/bash

# AWS Auto Scaling Group Demo - Create Resources Script
# Region: ap-south-1 (Mumbai)
# AMI: Ubuntu 22.04 LTS (Free Tier)

set -e  # Exit on any error

REGION="ap-south-1"
RESOURCE_FILE="created_resources.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to save resource IDs
save_resource() {
    echo "$1=$2" >> $RESOURCE_FILE
}

# Error handling function
handle_error() {
    print_error "Script failed at line $1. Check the error above."
    exit 1
}

trap 'handle_error $LINENO' ERR

# Initialize resource tracking file
echo "# Created AWS Resources - $(date)" > $RESOURCE_FILE

print_status "Starting AWS Auto Scaling Group Demo Setup..."
print_status "Region: $REGION"

# Step 1: Create VPC
print_status "Step 1: Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --region $REGION \
    --query 'Vpc.VpcId' \
    --output text)

if [ -z "$VPC_ID" ]; then
    print_error "Failed to create VPC"
    exit 1
fi

print_status "VPC created: $VPC_ID"
save_resource "VPC_ID" "$VPC_ID"

# Enable DNS hostnames for VPC
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames \
    --region $REGION

# Step 2: Create and attach Internet Gateway
print_status "Step 2: Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --region $REGION \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

print_status "Internet Gateway created: $IGW_ID"
save_resource "IGW_ID" "$IGW_ID"

# Attach IGW to VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID \
    --region $REGION

print_status "Internet Gateway attached to VPC"

# Step 3: Create two public subnets
print_status "Step 3: Creating two public subnets..."

# Subnet 1 in AZ a
SUBNET1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone ${REGION}a \
    --region $REGION \
    --query 'Subnet.SubnetId' \
    --output text)

print_status "Subnet 1 created: $SUBNET1_ID (${REGION}a)"
save_resource "SUBNET1_ID" "$SUBNET1_ID"

# Subnet 2 in AZ b
SUBNET2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone ${REGION}b \
    --region $REGION \
    --query 'Subnet.SubnetId' \
    --output text)

print_status "Subnet 2 created: $SUBNET2_ID (${REGION}b)"
save_resource "SUBNET2_ID" "$SUBNET2_ID"

# Enable auto-assign public IP for both subnets
aws ec2 modify-subnet-attribute \
    --subnet-id $SUBNET1_ID \
    --map-public-ip-on-launch \
    --region $REGION

aws ec2 modify-subnet-attribute \
    --subnet-id $SUBNET2_ID \
    --map-public-ip-on-launch \
    --region $REGION

print_status "Auto-assign public IP enabled for both subnets"

# Step 4: Create Route Table and configure routing
print_status "Step 4: Creating Route Table..."

RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --region $REGION \
    --query 'RouteTable.RouteTableId' \
    --output text)

print_status "Route Table created: $RT_ID"
save_resource "RT_ID" "$RT_ID"

# Add route to Internet Gateway
aws ec2 create-route \
    --route-table-id $RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID \
    --region $REGION

# Associate route table with both subnets
aws ec2 associate-route-table \
    --route-table-id $RT_ID \
    --subnet-id $SUBNET1_ID \
    --region $REGION

aws ec2 associate-route-table \
    --route-table-id $RT_ID \
    --subnet-id $SUBNET2_ID \
    --region $REGION

print_status "Route table configured and associated with subnets"

# Create Security Group for Load Balancer
print_status "Creating Security Group for Load Balancer..."

LB_SG_ID=$(aws ec2 create-security-group \
    --group-name autoscaling-lb-sg \
    --description "Security group for Auto Scaling Load Balancer" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --query 'GroupId' \
    --output text)

print_status "Load Balancer Security Group created: $LB_SG_ID"
save_resource "LB_SG_ID" "$LB_SG_ID"

# Add HTTP rule to LB security group
aws ec2 authorize-security-group-ingress \
    --group-id $LB_SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $REGION

# Create Security Group for EC2 instances
print_status "Creating Security Group for EC2 instances..."

EC2_SG_ID=$(aws ec2 create-security-group \
    --group-name autoscaling-ec2-sg \
    --description "Security group for Auto Scaling EC2 instances" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --query 'GroupId' \
    --output text)

print_status "EC2 Security Group created: $EC2_SG_ID"
save_resource "EC2_SG_ID" "$EC2_SG_ID"

# Add HTTP and SSH rules to EC2 security group
aws ec2 authorize-security-group-ingress \
    --group-id $EC2_SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $REGION

aws ec2 authorize-security-group-ingress \
    --group-id $EC2_SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region $REGION

# Step 5: Create Target Group
print_status "Step 5: Creating Target Group..."

TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name autoscaling-target-group \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --health-check-path / \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --region $REGION \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

print_status "Target Group created: $TARGET_GROUP_ARN"
save_resource "TARGET_GROUP_ARN" "$TARGET_GROUP_ARN"

# Create Application Load Balancer
print_status "Creating Application Load Balancer..."

LB_ARN=$(aws elbv2 create-load-balancer \
    --name autoscaling-load-balancer \
    --subnets $SUBNET1_ID $SUBNET2_ID \
    --security-groups $LB_SG_ID \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --region $REGION \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

print_status "Load Balancer created: $LB_ARN"
save_resource "LB_ARN" "$LB_ARN"

# Get Load Balancer DNS name
LB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $LB_ARN \
    --region $REGION \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

print_status "Load Balancer DNS: $LB_DNS"
save_resource "LB_DNS" "$LB_DNS"

# Create Listener for Load Balancer
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $LB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN \
    --region $REGION \
    --query 'Listeners[0].ListenerArn' \
    --output text)

print_status "Load Balancer Listener created: $LISTENER_ARN"
save_resource "LISTENER_ARN" "$LISTENER_ARN"

# Get Ubuntu AMI ID (latest Ubuntu 22.04 LTS)
print_status "Getting latest Ubuntu 22.04 LTS AMI..."

AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
              "Name=state,Values=available" \
    --region $REGION \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text)

print_status "Using Ubuntu AMI: $AMI_ID"
save_resource "AMI_ID" "$AMI_ID"

# Create Launch Template
print_status "Creating Launch Template..."

USER_DATA=$(cat << 'EOF'
#!/bin/bash
yes|sudo apt update
yes|sudo apt install apache2
sudo systemctl restart apache2
echo "<h1>Server details</h1>
<p>hostname:$(hostname)</p>
<p>ip address:$(hostname -I | cut -d ' ' -f1)</p>" | sudo tee /var/www/html/index.html > /dev/null
EOF
)

USER_DATA_BASE64=$(echo "$USER_DATA" | base64 -w 0)

LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
    --launch-template-name autoscaling-launch-template \
    --launch-template-data "{
        \"ImageId\":\"$AMI_ID\",
        \"InstanceType\":\"t2.micro\",
        \"UserData\":\"$USER_DATA_BASE64\",
        \"NetworkInterfaces\":[{
            \"AssociatePublicIpAddress\":true,
            \"DeviceIndex\":0,
            \"Groups\":[\"$EC2_SG_ID\"]
        }]
    }" \
    --region $REGION \
    --query 'LaunchTemplate.LaunchTemplateId' \
    --output text)

print_status "Launch Template created: $LAUNCH_TEMPLATE_ID"
save_resource "LAUNCH_TEMPLATE_ID" "$LAUNCH_TEMPLATE_ID"

# Create Auto Scaling Group with unique name
print_status "Creating Auto Scaling Group..."

TIMESTAMP=$(date +%s)
ASG_NAME="autoscaling-demo-asg-$TIMESTAMP"

# Check if ASG with base name exists and wait if needed
EXISTING_ASG=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names autoscaling-demo-asg \
    --region $REGION \
    --query 'AutoScalingGroups[0].AutoScalingGroupName' \
    --output text 2>/dev/null || echo "None")

if [ "$EXISTING_ASG" != "None" ] && [ "$EXISTING_ASG" != "null" ]; then
    print_warning "Found existing ASG 'autoscaling-demo-asg' - using unique name: $ASG_NAME"
fi

aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --launch-template "LaunchTemplateId=$LAUNCH_TEMPLATE_ID,Version=\$Latest" \
    --min-size 1 \
    --max-size 3 \
    --desired-capacity 2 \
    --target-group-arns $TARGET_GROUP_ARN \
    --health-check-type ELB \
    --health-check-grace-period 300 \
    --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID" \
    --region $REGION

print_status "Auto Scaling Group created: $ASG_NAME"
save_resource "ASG_NAME" "$ASG_NAME"

print_status "✅ All resources created successfully!"
print_status ""
print_status "📋 Summary:"
print_status "- VPC: $VPC_ID"
print_status "- Internet Gateway: $IGW_ID"
print_status "- Subnets: $SUBNET1_ID, $SUBNET2_ID (with auto-assign public IP)"
print_status "- Route Table: $RT_ID"
print_status "- Security Groups: $LB_SG_ID (LB), $EC2_SG_ID (EC2)"
print_status "- Target Group: $TARGET_GROUP_ARN"
print_status "- Load Balancer: $LB_ARN"
print_status "- Load Balancer DNS: $LB_DNS"
print_status "- Launch Template: $LAUNCH_TEMPLATE_ID (with auto-assign public IP)"
print_status "- Auto Scaling Group: $ASG_NAME"
print_status ""
print_status "🌐 Access your application at: http://$LB_DNS"
print_status ""
print_warning "⏳ Wait 5-10 minutes for instances to launch and health checks to pass"
print_status ""
print_status "🔍 To check individual EC2 instances:"
print_status "aws ec2 describe-instances --filters \"Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME\" --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]' --output table --region $REGION"
print_status ""
print_status "All resource IDs saved to: $RESOURCE_FILE"