# IAM Instance Profile for the AWS ALB role
resource "aws_iam_instance_profile" "k8s_aws_alb_iam_profile" {
  name = "aws_instance_profile"
  role = aws_iam_role.k8s-aws-alb-role.name
}

# IAM Role for the AWS ALB Controller
resource "aws_iam_role" "k8s-aws-alb-role" {
  name = "k8s-aws-alb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = ["ec2.amazonaws.com"]
      }
    }]
  })
}

# Attach Custom Policy to the IAM Role
resource "aws_iam_role_policy_attachment" "aws_lb_policy" {
  policy_arn = aws_iam_policy.k8s_aws_alb_custom_policy.arn
  role       = aws_iam_role.k8s-aws-alb-role.name
}

# Custom IAM Policy for AWS Load Balancer Controller
resource "aws_iam_policy" "k8s_aws_alb_custom_policy" {
  name        = "k8s-aws-alb-custom-policy"
  description = "Policy for AWS Load Balancer Controller to manage ALB resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow creating Service Linked Role for Elastic Load Balancing
      {
        Effect = "Allow"
        Action = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      
      # Describe EC2 and Elastic Load Balancing resources
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },

      # Allow actions for Cognito, ACM, WAF, Shield, and IAM
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "shield:GetSubscriptionState"
        ]
        Resource = "*"
      },

      # Manage Security Groups
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
      },

      # Manage Tags for Security Groups
      {
        Effect = "Allow"
        Action = ["ec2:CreateTags", "ec2:DeleteTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "true"
          }
        }
      },

      # Allow ALB creation and management
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroupAttributes"
        ]
        Resource = "*"
      },

      # Allow ALB tagging
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/*/*",
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        ]
      },

      # Allow Register/Deregister ALB Targets
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      }
    ]
  })
}


output "k8s_iam_instance_profile" {
  value = aws_iam_instance_profile.k8s_aws_alb_iam_profile.name
}