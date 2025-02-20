provider "aws" {
  region = "eu-central-1" # Change to your preferred region
}

resource "aws_iam_role" "windows_server_role" {
  name               = "WindowsServerRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "s3_ssm_access" {
  name        = "S3SSMAccessPolicy"
  description = "Policy to allow access to S3 and SSM"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::iis-logs-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": "ssm:GetParameter",
      "Resource": "arn:aws:ssm:us-east-1::parameter/iis-config/*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.windows_server_role.name
  policy_arn = aws_iam_policy.s3_ssm_access.arn
}

resource "aws_iam_instance_profile" "windows_instance_profile" {
  name = "WindowsInstanceProfile"
  role = aws_iam_role.windows_server_role.name
}

resource "aws_s3_bucket" "iis_logs_bucket" {
  bucket = "iis-logs-bucket"
  versioning {
    enabled = true
  }
}

resource "aws_ssm_pWarameter" "iis_config" {
  name  = "/iis-config/site-name"
  type  = "String"
  value = "MyIISWebsite"
}

resource "aws_instance" "windows_server" {
  ami                         = "ami-0bdb1d6c15a40392c" # Windows Server 2022 AMI ID (Check latest in your region)
  instance_type               = "t3.medium"
  key_name                    = "my-key-pair" # Change to your SSH key
  iam_instance_profile        = aws_iam_instance_profile.windows_instance_profile.name
  associate_public_ip_address = true

  tags = {
    Name = "WindowsServer2022"
  }
}
