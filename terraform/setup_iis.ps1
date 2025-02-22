# setup_iis.ps1

# Import AWS PowerShell Module
Import-Module AWSPowerShell -Force

# Retrieve parameters from SSM
try {
    $SiteName = (Get-SSMParameter -Name "/iis/site_name").Value
}
catch {
    Write-Error "Error retrieving SiteName: $_"
}

try {
    $AppSetting = (Get-SSMParameter -Name "/iis/app_setting" -WithDecryption $true).Value
}
catch {
    Write-Error "Error retrieving AppSetting: $_"
}

# Install Web-Server Role
try {
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
}
catch {
    Write-Error "Error installing Web-Server Role: $_"
}

# Create Website Directory (with check)
if (!(Test-Path -Path "C:\inetpub\wwwroot\MyWebsite")) {
    try {
        New-Item -ItemType Directory -Path "C:\inetpub\wwwroot\MyWebsite"
    }
    catch {
        Write-Error "Error creating website directory: $_"
    }
}

# Create a simple HTML file for testing
@"
<html>
<head><title>$SiteName</title></head>
<body>
<h1>Website Deployed!</h1>
<p>Site Name: $SiteName</p>
<p>App Setting: $AppSetting</p>
</body>
</html>
"@ | Out-File -FilePath "C:\inetpub\wwwroot\MyWebsite\index.html"

# Create Website
try {
    New-Website -Name "MyWebsite" -Port 80 -PhysicalPath "C:\inetpub\wwwroot\MyWebsite"
}
catch {
    Write-Error "Error creating website: $_"
}

# Enable IIS Logging
try {
    Set-ItemProperty -Path "IIS:\Sites\MyWebsite" -Name logfile.directory -Value "C:\inetpub\logs\LogFiles"
}
catch {
    Write-Error "Error enabling IIS logging: $_"
}

# Scheduled Task for Log Upload (with check)
$taskName = "UploadIISLogs"
if (!(Get-ScheduledTask -TaskName $taskName)) {
    try {
        $Action = New-ScheduledTaskAction -Execute "C:\Program Files\Amazon\AWSCLIV2\aws.exe" -Argument "s3 cp C:\inetpub\logs\LogFiles s3://iis-logs-unique-bucket-name/logs --recursive"
        $Trigger = New-ScheduledTaskTrigger -Daily -At "00:00"
        Register-ScheduledTask -TaskName "UploadIISLogs" -Action $Action -Trigger $Trigger
    }
    catch {
        Write-Error "Error creating scheduled task: $_"
    }
}

# Start the task manually
try {
    Start-ScheduledTask -TaskName $taskName
}
catch {
    Write-Error "Error starting scheduled task: $_"
}

# Test Website
try {
    Invoke-WebRequest -Uri "http://localhost"
}
catch {
    Write-Error "Error testing website: $_"
}

# Test S3 Upload (optional, run manually or add a small test file)
# New-Item -ItemType File -Path "C:\inetpub\logs\LogFiles\test.txt"
# aws s3 cp C:\inetpub\logs\LogFiles\test.txt s3://iis-logs-unique-bucket-name/logs/