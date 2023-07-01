provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "sg_ssh_http_https_anywhere" {
  name        = "example-sg"
  description = "Example security group"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "test-web-instance" {
  ami = "ami-06b09bfacae1453cb" # Replace with your image. Here use Amazon Linux 2023 AMI 2023.1.20230629.0 x86_64 HVM kernel-6.1
  instance_type = "t2.micro"  # Replace with your desired instance type

  tags = {
    Name = "example-instance"
  }
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install httpd -y
    systemctl start httpd
    systemctl enable httpd
    cd /var/www/html

    # Fetch instance metadata using the token
    TOKEN=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 300" -H "X-aws-ec2-metadata-token: true" "http://169.254.169.254/latest/api/token")
    PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-type)

    # Create index.html
    echo "<!DOCTYPE html>
    <html>
    <head>
      <title>EC2 Metadata Example</title>
      <style>
        body {
          font-family: Arial, sans-serif;
        }

        h1 {
          color: #333;
        }

        h2 {
          color: #666;
          margin-top: 20px;
        }

        .red {
          color: red;
        }

        .green {
          color: green;
        }
      </style>
    </head>
    <body>
      <h1>EC2 Metadata</h1>

      <h2>Public IP:</h2>
      <pre class=\"red\">$PUBLIC_IP</pre>

      <h2>Instance ID:</h2>
      <pre class=\"green\">$INSTANCE_ID</pre>

      <h2>Instance Type:</h2>
      <pre class=\"green\">$INSTANCE_TYPE</pre>
    </body>
    </html>" > index.html
  EOF
  vpc_security_group_ids = [aws_security_group.sg_ssh_http_https_anywhere.id]
}

output "public_ip" {
  value = aws_instance.test-web-instance.public_ip
}