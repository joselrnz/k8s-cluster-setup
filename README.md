
# AWS Terraform Kubernetes Setup with Bastion Host

This guide provides step-by-step instructions to set up an AWS infrastructure using Terraform, including a VPC, public and private subnets, a Bastion host, security groups, and EC2 instances for Kubernetes.

---

## Prerequisites

1. **Install Terraform**  
   [Download and install Terraform](https://www.terraform.io/downloads).
2. **Install AWS CLI**  
   [Download and install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).
3. **Set Up SSH Keys**  
   Ensure you have an SSH key pair for accessing the Bastion host. The public key will be used in Terraform.

---

## Step 1: Export AWS Credentials

Make your AWS credentials available to Terraform by exporting them as environment variables.

```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="your-region"
```

Alternatively, you can configure credentials using the AWS CLI:

```bash
aws configure
```

---

## Step 2: Clone the Repository

Clone this repository to your local machine.

```bash
git clone https://github.com/your-repo/aws-terraform-k8s-setup.git
cd aws-terraform-k8s-setup
```

---

## Step 3: Customize Variables

Edit the `terraform.tfvars` file to configure your infrastructure.

```hcl
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
ami_id = "ami-04b4f1a9cf54c11d0"
bastion_instance_type = "t2.micro"
ec2_instance_type = "t2.medium"
key_name = "your-ssh-key-name"
my_ip = "your-public-ip/32" # Replace with your actual IP
```

---

## Step 4: Initialize Terraform

Run the following command to initialize the Terraform configuration.

```bash
terraform init
```

---

## Step 5: Validate Configuration

Ensure your configuration is valid.

```bash
terraform validate
```

---

## Step 6: Plan the Deployment

Review the changes Terraform will make to your AWS infrastructure.

```bash
terraform plan
```

---

## Step 7: Apply the Configuration

Deploy the infrastructure to AWS.

```bash
terraform apply
```

Type `yes` to confirm the deployment.

---

## Step 8: Connect to the Bastion Host

Once the infrastructure is deployed, you can connect to the Bastion host using SSH.

```bash
ssh -i ~/.ssh/your-private-key.pem ec2-user@<bastion-public-ip>
```

---

## Infrastructure Overview

### Components Deployed

1. **VPC**  
   - CIDR: `10.0.0.0/16`

2. **Public Subnet**  
   - CIDR: `10.0.1.0/24`

3. **Private Subnet**  
   - CIDR: `10.0.2.0/24`

4. **Bastion Host**  
   - Public-facing EC2 instance for secure SSH access.

5. **EC2 Instances**  
   - One Master Node
   - Two Worker Nodes

6. **Security Groups**  
   - Bastion: Allows SSH access from your IP.
   - Control Plane: Allows Kubernetes API and related traffic.
   - Worker Nodes: Allows Kubernetes-related traffic.

---

## Security Group Rules

### Bastion Host
| Protocol | Direction | Port Range | Source         | Purpose             |
|----------|-----------|------------|----------------|---------------------|
| TCP      | Inbound   | 22         | Your IP (`/32`) | SSH access          |

### Control Plane
| Protocol | Direction | Port Range | Source    | Purpose                  |
|----------|-----------|------------|-----------|--------------------------|
| TCP      | Inbound   | 6443       | 0.0.0.0/0 | Kubernetes API server    |
| TCP      | Inbound   | 2379-2380  | 0.0.0.0/0 | etcd server client API   |
| TCP      | Inbound   | 10250      | 0.0.0.0/0 | Kubelet API              |
| TCP      | Inbound   | 10259      | 0.0.0.0/0 | kube-scheduler           |
| TCP      | Inbound   | 10257      | 0.0.0.0/0 | kube-controller-manager  |

### Worker Nodes
| Protocol | Direction | Port Range      | Source    | Purpose            |
|----------|-----------|-----------------|-----------|--------------------|
| TCP      | Inbound   | 10250           | 0.0.0.0/0 | Kubelet API        |
| TCP      | Inbound   | 10256           | 0.0.0.0/0 | kube-proxy         |
| TCP      | Inbound   | 30000-32767     | 0.0.0.0/0 | NodePort Services  |
