# AWS IIS Terraform Setup

This repository provides Terraform scripts to provision an EC2 instance running Windows Server 2022 with IIS. The solution includes configuration for IIS, integration with AWS S3 for log storage, and automation for uploading IIS logs to S3 every minute.

## Prerequisites

- Terraform installed
- AWS CLI installed and configured with appropriate IAM credentials
- A valid AWS account

## Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/my-aws-iis-terraform.git
   cd my-aws-iis-terraform
   ```
