#!/bin/bash
set -o errexit -o nounset -o pipefail

if [ -z "${1:-}" ]
then
  echo Usage: $(basename "$0") STACK_NAME
  exit 1
fi

STACK_NAME="$1"
VPC_CIDR=10.0.0.0/16
PRIVATE_SUBNET_CIDR=10.0.0.0/17
PUBLIC_SUBNET_CIDR=10.0.128.0/20

echo "Creating Advance Template Dependencies"

vpc=$(aws ec2 create-vpc --cidr-block "$VPC_CIDR" --instance-tenancy default | jq -r .Vpc.VpcId)
aws ec2 wait vpc-available --vpc-ids "$vpc"
aws ec2 create-tags --resources "$vpc" --tags Key=Name,Value="$STACK_NAME"

ig=$(aws ec2 create-internet-gateway | jq -r .InternetGateway.InternetGatewayId)
aws ec2 attach-internet-gateway --internet-gateway-id "$ig" --vpc-id "$vpc"
aws ec2 create-tags --resources "$ig" --tags Key=Name,Value="$STACK_NAME"

AdminSecurityGroup=$(aws ec2 create-security-group --vpc-id "$vpc" --group-name AdminSecurityGroup --description "Admin Security Group" | jq -r .GroupId )
echo "AdminSecurityGroup: $AdminSecurityGroup"

bucket_status=$(aws s3 mb s3://${STACK_NAME}-cloudformation-bucket)
echo "ExhibitorS3Bucket: $bucket_status"

LbSecurityGroup=$(aws ec2 create-security-group --vpc-id "$vpc" --group-name LbSecurityGroup --description "Load Balancing Security Group" | jq -r .GroupId )
echo "LbSecurityGroup: $LbSecurityGroup"

MasterSecurityGroup=$(aws ec2 create-security-group --vpc-id "$vpc" --group-name MasterSecurityGroup --description "Master Security Group" | jq -r .GroupId )
echo "MasterSecurityGroup: $MasterSecurityGroup"

PrivateAgentSecurityGroup=$(aws ec2 create-security-group --vpc-id "$vpc" --group-name PrivateAgentSecurityGroup --description "Private Agent Security Group" | jq -r .GroupId )
echo "PrivateAgentSecurityGroup: $PrivateAgentSecurityGroup"

private_subnet=$(aws ec2 create-subnet --vpc-id "$vpc" --cidr-block "$PRIVATE_SUBNET_CIDR" | jq -r .Subnet.SubnetId)
aws ec2 wait subnet-available --subnet-ids "$private_subnet"
aws ec2 create-tags --resources "$private_subnet" --tags Key=Name,Value="${STACK_NAME}-private"
echo "Private SubnetId: $private_subnet"

PublicAgentSecurityGroup=$(aws ec2 create-security-group --vpc-id "$vpc" --group-name PublicAgentSecurityGroup --description "PublicAgentSecurityGroup" | jq -r .GroupId )
echo "PublicAgentSecurityGroup: $PublicAgentSecurityGroup"

public_subnet=$(aws ec2 create-subnet --vpc-id "$vpc" --cidr-block "$PUBLIC_SUBNET_CIDR" | jq -r .Subnet.SubnetId)
aws ec2 wait subnet-available --subnet-ids "$public_subnet"
aws ec2 create-tags --resources "$public_subnet" --tags Key=Name,Value="${STACK_NAME}-public"
echo "Public SubnetId: $public_subnet"
