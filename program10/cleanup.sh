#!/bin/bash

# AWS Auto Scaling Group Demo - Cleanup Script
# This script removes all resources created by create-autoscaling-demo.sh

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

# Function to safely delete resources with error handling
safe_delete() {
    local resource_type="$1"
    local resource_id="$2"
    local delete_command="$3"
    
    if [ -n "$resource_id" ] && [ "$resource_id" != "null" ]; then
        print_status "Deleting $resource_type: $resource_id"
        if eval "$delete_command"; then
            print_status "✅ $resource_type deleted successfully"
        else
            print_error "❌ Failed to delete $resource_type: $resource_id"
        fi
    else
        print_warning "⚠️  $resource_type ID not found or already deleted"
    fi
}

# Check if resource file exists
if [ ! -f "$RESOURCE_FILE" ]; then
    print_error "Resource file '$RESOURCE_FILE' not found!"
    print_error "Make sure you run this script in the same directory as the create script"
    exit 1
fi

print_status "Starting cleanup of AWS Auto Scaling Group Demo resources..."
print_status "Reading resource IDs from: $RESOURCE_FILE"
print_status ""

# Source the resource file to get variables
source "$RESOURCE_FILE"

# Step 1: Delete Auto Scaling Group
print_status "Step 1: Deleting Auto Scaling Group..."
if [ -n "$ASG_NAME" ]; then
    # First, set desired capacity to 0
    aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name "$ASG_NAME" \
        --min-size 0 \
        --max-size 0 \
        --desired-capacity 0 \
        --region $REGION 2>/dev/null || true
    
    print_status "Waiting for instances to terminate..."
    aws autoscaling wait instances-terminated \
        --auto-scaling-group-names "$ASG_NAME" \
        --region $REGION 2>/dev/null || true
    
    safe_delete "Auto Scaling Group" "$ASG_NAME" \
        "aws autoscaling delete-auto-scaling-group --auto-scaling-group-name '$ASG_NAME' --force-delete --region $REGION"
else
    print_warning "Auto Scaling Group name not found"
fi

# Step 2: Delete Launch Template
print_status "Step 2: Deleting Launch Template..."
safe_delete "Launch Template" "$LAUNCH_TEMPLATE_ID" \
    "aws ec2 delete-launch-template --launch-template-id '$LAUNCH_TEMPLATE_ID' --region $REGION"

# Step 3: Delete Load Balancer and related resources
print_status "Step 3: Deleting Load Balancer resources..."

# Delete Listener
safe_delete "Load Balancer Listener" "$LISTENER_ARN" \
    "aws elbv2 delete-listener --listener-arn '$LISTENER_ARN' --region $REGION"

# Delete Load Balancer
if [ -n "$LB_ARN" ]; then
    safe_delete "Load Balancer" "$LB_ARN" \
        "aws elbv2 delete-load-balancer --load-balancer-arn '$LB_ARN' --region $REGION"
    
    print_status "Waiting for Load Balancer to be deleted..."
    aws elbv2 wait load-balancer-not-exists --load-balancer-arns "$LB_ARN" --region $REGION 2>/dev/null || true
fi

# Delete Target Group
safe_delete "Target Group" "$TARGET_GROUP_ARN" \
    "aws elbv2 delete-target-group --target-group-arn '$TARGET_GROUP_ARN' --region $REGION"

# Step 4: Delete Security Groups
print_status "Step 4: Deleting Security Groups..."

# Wait a bit for load balancer to fully delete before deleting security groups
sleep 30

safe_delete "EC2 Security Group" "$EC2_SG_ID" \
    "aws ec2 delete-security-group --group-id '$EC2_SG_ID' --region $REGION"

safe_delete "Load Balancer Security Group" "$LB_SG_ID" \
    "aws ec2 delete-security-group --group-id '$LB_SG_ID' --region $REGION"

# Step 5: Delete Route Table associations and routes
print_status "Step 5: Cleaning up Route Table..."

if [ -n "$RT_ID" ]; then
    # Get association IDs
    ASSOCIATIONS=$(aws ec2 describe-route-tables \
        --route-table-ids "$RT_ID" \
        --region $REGION \
        --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' \
        --output text 2>/dev/null || true)
    
    if [ -n "$ASSOCIATIONS" ] && [ "$ASSOCIATIONS" != "None" ]; then
        for assoc_id in $ASSOCIATIONS; do
            print_status "Disassociating route table association: $assoc_id"
            aws ec2 disassociate-route-table \
                --association-id "$assoc_id" \
                --region $REGION 2>/dev/null || true
        done
    fi
    
    # Delete custom routes (not local ones)
    print_status "Deleting custom routes from route table"
    aws ec2 delete-route \
        --route-table-id "$RT_ID" \
        --destination-cidr-block 0.0.0.0/0 \
        --region $REGION 2>/dev/null || true
fi

# Step 6: Delete Subnets
print_status "Step 6: Deleting Subnets..."
safe_delete "Subnet 1" "$SUBNET1_ID" \
    "aws ec2 delete-subnet --subnet-id '$SUBNET1_ID' --region $REGION"

safe_delete "Subnet 2" "$SUBNET2_ID" \
    "aws ec2 delete-subnet --subnet-id '$SUBNET2_ID' --region $REGION"

# Step 7: Delete Route Table
print_status "Step 7: Deleting Route Table..."
safe_delete "Route Table" "$RT_ID" \
    "aws ec2 delete-route-table --route-table-id '$RT_ID' --region $REGION"

# Step 8: Detach and Delete Internet Gateway
print_status "Step 8: Deleting Internet Gateway..."
if [ -n "$IGW_ID" ] && [ -n "$VPC_ID" ]; then
    print_status "Detaching Internet Gateway from VPC"
    aws ec2 detach-internet-gateway \
        --internet-gateway-id "$IGW_ID" \
        --vpc-id "$VPC_ID" \
        --region $REGION 2>/dev/null || true
fi

safe_delete "Internet Gateway" "$IGW_ID" \
    "aws ec2 delete-internet-gateway --internet-gateway-id '$IGW_ID' --region $REGION"

# Step 9: Delete VPC
print_status "Step 9: Deleting VPC..."
safe_delete "VPC" "$VPC_ID" \
    "aws ec2 delete-vpc --vpc-id '$VPC_ID' --region $REGION"

print_status ""
print_status "✅ Cleanup completed!"
print_status ""
print_status "🗑️  The following resources have been cleaned up:"
print_status "- Auto Scaling Group: ${ASG_NAME:-'Not found'}"
print_status "- Launch Template: ${LAUNCH_TEMPLATE_ID:-'Not found'}"
print_status "- Load Balancer: ${LB_ARN:-'Not found'}"
print_status "- Target Group: ${TARGET_GROUP_ARN:-'Not found'}"
print_status "- Security Groups: ${EC2_SG_ID:-'Not found'}, ${LB_SG_ID:-'Not found'}"
print_status "- Route Table: ${RT_ID:-'Not found'}"
print_status "- Subnets: ${SUBNET1_ID:-'Not found'}, ${SUBNET2_ID:-'Not found'}"
print_status "- Internet Gateway: ${IGW_ID:-'Not found'}"
print_status "- VPC: ${VPC_ID:-'Not found'}"
print_status ""
print_warning "💡 You can now safely delete the resource file: $RESOURCE_FILE"

# Ask if user wants to delete the resource file
read -p "Do you want to delete the resource tracking file ($RESOURCE_FILE)? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$RESOURCE_FILE"
    print_status "Resource file deleted."
else
    print_status "Resource file kept for reference."
fi