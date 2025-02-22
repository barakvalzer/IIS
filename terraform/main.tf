# main.tf

provider "aws" {
  region = "eu-central-1"
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "windows_sg" {
  name        = "windows-sg"
  description = "Allow RDP and HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict in production
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "iis_logs" {
  bucket = "iis-logs-unique-bucket-name" #Replace with unique name.
  versioning {
    enabled = true
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "EC2-SSM-S3-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
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

resource "aws_iam_policy" "s3_policy" {
  name = "S3-Access-Policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.iis_logs.arn,
          "${aws_s3_bucket.iis_logs.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_policy" {
  name = "SSM-Access-Policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DescribeParameters"
        ],
        Effect   = "Allow"
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_ssm_parameter" "site_name" {
  name  = "/iis/site_name"
  type  = "String"
  value = "MyWebsite"
}

resource "aws_ssm_parameter" "app_setting" {
  name  = "/iis/app_setting"
  type  = "SecureString"
  value = "YourSecretValue"
}

resource "aws_instance" "windows_server" {
  ami                    = "ami-0fb94f7ede485f4fe" # Replace with your AMI
  instance_type          = "t3.medium"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.windows_sg.id]
  key_name               = "my-key-pair" # Replace with your key pair name
  root_block_device {
    volume_size = 50
    volume_type = "gp2"
  }
  user_data = <<-EOF
<powershell>
  Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "AWSCLIV2.msi"
  Start-Process msiexec.exe -Wait -ArgumentList "/i AWSCLIV2.msi /quiet"
  Install-Module -Name AWSPowerShell.SSM -Force
</powershell>
EOF
  #   provisioner "local-exec" {
  #     command = "powershell.exe -ExecutionPolicy Bypass -File setup_iis.ps1"
  #   }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2-SSM-S3-Profile"
  role = aws_iam_role.ec2_role.name
}

variable "aws_region" {
  default = "eu-central-1"
}
