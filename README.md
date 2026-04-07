# Gitea on AWS

A self-hosted Git service deployed on AWS using Terraform.

## Business Goal
Provide a private, self-hosted code hosting platform for development teams who want full control over their data without relying on third-party services like GitHub.

## Target Users
Small to medium development teams who require:
- Private code repositories
- Self-managed infrastructure
- Data privacy and security

## Architecture
- **EC2** (t2.micro) - Hosts the Gitea application
- **RDS** (PostgreSQL, db.t3.micro) - Database for Gitea
- **VPC** - Custom network with public subnet
- **Security Groups** - Controls access to EC2 and RDS
- **CloudWatch** - Monitors CPU and storage metrics

## Tech Stack
- Gitea 1.21.11
- PostgreSQL 16.6
- Terraform
- AWS (EC2, RDS, VPC, CloudWatch)

## Deployment

### Prerequisites
- AWS CLI configured
- Terraform installed

### Steps
1. Clone this repository
2. Configure AWS credentials
3. Run Terraform
```bash
terraform init
terraform plan
terraform apply
```

4. Access Gitea at `http://<EC2_PUBLIC_IP>:3000`

## License
MIT