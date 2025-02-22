# AWS IIS Terraform Setup

This repository provides Terraform scripts to provision an EC2 instance running Windows Server 2022 with IIS. The solution includes configuration for IIS, integration with AWS S3 for log storage, and automation for uploading IIS logs to S3 every minute.

## Prerequisites

- Terraform installed
- AWS CLI installed and configured with appropriate IAM credentials
- A valid AWS account
- Generated key for windows machines

## Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/barakvalzer/IIS.git
   cd IIS
   ```
2. **Modify terraform/main.tf and setup_iis.ps1**

3. **Run Terraform**
   ```bash
   cd terraform
   terraform plan/terraform apply
   ```
4. **copy setup_iis.ps1 to created windows instance**

5. **run powershell script to configure IIS + HTML + Logs to S3**
