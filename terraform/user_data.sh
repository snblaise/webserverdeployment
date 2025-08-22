#!/bin/bash

# Update system packages
dnf update -y

# Install required packages
dnf install -y httpd php amazon-cloudwatch-agent

# Start and enable services
systemctl start httpd
systemctl enable httpd

# Create a dynamic PHP page
cat > /var/www/html/index.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>${project_name} - ${environment}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { color: #232F3E; }
        .info { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1 class="header">Welcome to ${project_name}</h1>
    <div class="info">
        <h2>Environment: ${environment}</h2>
        <p>Instance ID: <?php echo shell_exec('curl -s http://169.254.169.254/latest/meta-data/instance-id'); ?></p>
        <p>Availability Zone: <?php echo shell_exec('curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone'); ?></p>
        <p>Instance Type: <?php echo shell_exec('curl -s http://169.254.169.254/latest/meta-data/instance-type'); ?></p>
        <p>Server Time: <?php echo date('D M j H:i:s T Y'); ?></p>
    </div>
</body>
</html>
EOF

# Create index.html that redirects to PHP
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="refresh" content="0; url=index.php">
    <title>Redirecting...</title>
</head>
<body>
    <p>Redirecting to dynamic page...</p>
</body>
</html>
EOF

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/httpd/access_log",
                        "log_group_name": "/aws/ec2/${project_name}-${environment}/httpd/access",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/httpd/error_log",
                        "log_group_name": "/aws/ec2/${project_name}-${environment}/httpd/error",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Enable CloudWatch Agent service
systemctl enable amazon-cloudwatch-agent