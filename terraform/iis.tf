provider "aws" {
  region = "eu-central-1"
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "instance_role" {
  name = "EC2InstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for S3 & SSM Access
resource "aws_iam_policy" "s3_ssm_policy" {
  name        = "S3SSMAccessPolicy-Unique"
  description = "S3 and SSM access for EC2 instance"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::my-unique-iis-logs-bucket/*"
      },
      {
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach Policy to IAM Role
resource "aws_iam_role_policy_attachment" "s3_ssm_attach" {
  policy_arn = aws_iam_policy.s3_ssm_policy.arn
  role       = aws_iam_role.instance_role.name
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "windows_instance_profile" {
  name = "windows-instance-profile"
  role = aws_iam_role.instance_role.name
}

# Security Group for IIS & RDP
resource "aws_security_group" "windows_sg" {
  name        = "windows-sg"
  description = "Allow RDP and HTTP traffic"

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow RDP access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Windows Server 2022 EC2 Instance
resource "aws_instance" "windows_server" {
  ami                    = "ami-0fb94f7ede485f4fe"
  instance_type          = "t3.micro"
  key_name               = "my-key-pair"
  vpc_security_group_ids = [aws_security_group.windows_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.windows_instance_profile.name

  # Install IIS, .NET Core, AWS CLI, and Log Upload Script
  user_data = <<-EOF
    <powershell>
    # Install IIS
    Install-WindowsFeature -name Web-Server -IncludeManagementTools

    # Install .NET Core Hosting Bundle
    Invoke-WebRequest -Uri "https://download.visualstudio.microsoft.com/download/pr/6d8a45c9-9f92-4c7e-892f-61f7f25cbfbf/0f6a77c06a7b357fb156ad2edcd8c07c/dotnet-hosting-7.0.5-win.exe" -OutFile "dotnet-hosting.exe"
    Start-Process -FilePath "dotnet-hosting.exe" -ArgumentList "/quiet" -Wait

    # Install AWS CLI
    Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "AWSCLIV2.msi"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i AWSCLIV2.msi /quiet" -Wait

    # Create IIS website folder
    New-Item -Path "C:\\inetpub\\wwwroot\\myapp" -ItemType Directory -Force

    # Create a simple HTML file
    Set-Content -Path "C:\\inetpub\\wwwroot\\myapp\\index.html" -Value "<h1>Welcome to My IIS Website</h1>"

    # Create IIS site
    New-WebSite -Name "MyApp" -PhysicalPath "C:\\inetpub\\wwwroot\\myapp" -Port 80 -Force

    # Set up IIS log upload script
    $logScript = @"
    `$bucketName = 'my-unique-iis-logs-bucket'
    `$logPath = 'C:\\inetpub\\logs\\LogFiles\\*'

    aws s3 cp `$logPath s3://`$bucketName/ --recursive
    "@

    $logScript | Out-File "C:\\scripts\\upload_logs.ps1" -Encoding utf8

    # Create Scheduled Task to run script daily
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\\scripts\\upload_logs.ps1"
    $trigger = New-ScheduledTaskTrigger -Daily -At "12:00AM"
    Register-ScheduledTask -TaskName "UploadIISLogs" -Action $action -Trigger $trigger -User "NT AUTHORITY\\SYSTEM" -RunLevel Highest -Force

    Write-Output "IIS and dependencies installed successfully."
    </powershell>
  EOF

  tags = {
    Name = "WindowsServer2022"
  }
}

# S3 Bucket for IIS Logs
resource "aws_s3_bucket" "iis_logs" {
  bucket = "my-unique-iis-logs-bucket"
  versioning {
    enabled = true
  }
}

# SSM Parameter Store - IIS Config
resource "aws_ssm_parameter" "iis_config" {
  name        = "/myapp/website/config"
  description = "IIS website configuration"
  type        = "SecureString"
  value       = "{\"site_name\":\"MyWebsite\",\"port\":80}"
}
