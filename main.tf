
provider "aws" {
  region = "us-east-1"
}

data "aws_vpcs" "all_vpcs" {
}

variable "cidr-Web-VPC" {
  default = "192.168.0.0/16"
}

variable "cidr-RDS-VPC" {
  default = "10.0.0.0/16"
}

variable "cidr-sub1-WEBVPC" {
  default = "192.168.1.0/24"
}

variable "cidr-sub1-RDSVPC" {
  default = "10.0.1.0/24"
}

variable "AZ" {
  default = "us-east-1a"
}

output "vpc_ids" {
  value = data.aws_vpcs.all_vpcs.ids
}

resource "aws_vpc" "Web" {
  cidr_block = var.cidr-Web-VPC
  #cidr_block       = "192.168.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "Web-VPC"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.Web.id

  tags = {
    Name = "gw-web"
  }
}
resource "aws_vpc" "RDS" {
  cidr_block = var.cidr-RDS-VPC
  #cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "RDS-VPC"
  }
}

resource "aws_subnet" "web-sub1" {
  vpc_id            = aws_vpc.Web.id
  cidr_block        = var.cidr-sub1-WEBVPC
  availability_zone = var.AZ
  tags = {
    Name = "sub1-10.0.1.0/24-RDS-VPC"
  }
}

resource "aws_subnet" "rds-sub1" {
  vpc_id            = aws_vpc.RDS.id
  cidr_block        = var.cidr-sub1-RDSVPC
  availability_zone = var.AZ
  tags = {
    Name = "sub1-192.168.1.0/24-WEB-VPC"
  }
}

resource "aws_route_table" "rt-web" {
  vpc_id = aws_vpc.Web.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "rt-web"
  }
}

resource "aws_route_table_association" "sub1-web-rt-as" {
  subnet_id      = aws_subnet.web-sub1.id
  route_table_id = aws_route_table.rt-web.id
}

resource "aws_security_group" "sg-icmp-WEBVPC" {
  name   = "icmp-sg"
  vpc_id = aws_vpc.Web.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "icmp"
  }
}

resource "aws_security_group" "sg-icmp-RDSVPC" {
  name   = "icmp-sg"
  vpc_id = aws_vpc.RDS.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "icmp"
  }
}

resource "aws_security_group" "sg_ssh_http_https_anywhere" {
  name        = "web-sg"
  description = "security group for Web Server"
  vpc_id      = aws_vpc.Web.id
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
  tags = {
    Name = "allow_http_https_ssh"
  }
}
resource "aws_instance" "test-web-instance-WEB" {
  count                       = 2
  subnet_id                   = aws_subnet.web-sub1.id
  associate_public_ip_address = true # This enables the public IP association
  #subnet_id       = "subnet-0b6ef88cf9d06f1c9"
  ami                    = "ami-06b09bfacae1453cb" # Replace with your image. Here use Amazon Linux 2023 AMI 2023.1.20230629.0 x86_64 HVM kernel-6.1
  instance_type          = "t2.micro"              # Replace with your desired instance type
  vpc_security_group_ids = ["${aws_security_group.sg-icmp-WEBVPC.id}"]
  tags = {
    Name = "example-for peering"
  }
}

resource "aws_instance" "test-web-instance-RDS" {
  count                       = 2
  subnet_id                   = aws_subnet.rds-sub1.id
  associate_public_ip_address = true # This enables the public IP association

  #subnet_id       = "subnet-0b6ef88cf9d06f1c9"
  ami                    = "ami-06b09bfacae1453cb" # Replace with your image. Here use Amazon Linux 2023 AMI 2023.1.20230629.0 x86_64 HVM kernel-6.1
  instance_type          = "t2.micro"              # Replace with your desired instance type
  vpc_security_group_ids = ["${aws_security_group.sg-icmp-RDSVPC.id}"]
  tags = {
    Name = "example-for peering RDS"
  }
}
/*resource "aws_db_instance" "rds_instance" {
  #identifier = "rds-terraform"
  allocated_storage    = 5
  db_name              = "wordpress"
  engine               = "mysql"
  engine_version       = "8.0.28"
  instance_class       = "db.t3.micro"
  username             = "wordpress"
  password             = "wordpress"
  #parameter_group_name = "default.mysql5.7"
  publicly_accessible    = false
  skip_final_snapshot  = false
  availability_zone = var.AZ
  vpc_security_group_ids = ["${aws_security_group.sg_ssh_http_https_anywhere.id}"]
  tags = {
    Name = "WordPressRDSServerInstance"
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "efs-security-group"
  description = "Security group for EFS"

  ingress {
    from_port   = 2049
    to_port     = 2059
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


resource "aws_efs_file_system" "efs_example" {
  creation_token   = "efs-example"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name = "efs-example"
  }
}

resource "aws_efs_mount_target" "efs_mount" {
  file_system_id = aws_efs_file_system.efs_example.id
  count          = length(data.aws_vpcs.all_vpcs.ids)
  #vpc_id          = data.aws_vpcs.all_vpcs.ids[count.index]
  subnet_id       = "subnet-0b6ef88cf9d06f1c9"
  security_groups = [aws_security_group.efs_sg.id]
}


resource "aws_instance" "test-web-instance" {
  depends_on    = [aws_efs_file_system.efs_example]
  count         = 2
  subnet_id       = "subnet-0b6ef88cf9d06f1c9"
  ami           = "ami-06b09bfacae1453cb" # Replace with your image. Here use Amazon Linux 2023 AMI 2023.1.20230629.0 x86_64 HVM kernel-6.1
  instance_type = "t2.micro"              # Replace with your desired instance type

  tags = {
    Name = "example-instance"
  }
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install httpd unzip nfs-common -y
    systemctl start httpd
    systemctl enable httpd
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    cd /var/www/html

    EFS_MOUNT_POINT="/mnt/efs"

    EFS_FILE_SYSTEM_ID = "${aws_efs_file_system.efs_example.id}"
    sudo mkdir -p $EFS_MOUNT_POINT

    # Mount the EFS file system
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $EFS_FILE_SYSTEM_ID.efs.us-east-1.amazonaws.com:/ $EFS_MOUNT_POINT
  
    # Add entry to /etc/fstab for automatic mount on reboot
    echo "$EFS_FILE_SYSTEM_ID.efs.us-east-1.amazonaws.com:/ $EFS_MOUNT_POINT nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0" | sudo tee -a /etc/fstab

    # Fetch instance metadata using the token
    TOKEN=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 300" -H "X-aws-ec2-metadata-token: true" "http://169.254.169.254/latest/api/token")
    PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-type)
    AVAILABILITY_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
    PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

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
      
      <h2>Availability Zone:</h2>
      <pre class=\"green\">$AVAILABILITY_ZONE</pre>

      <h2>Private IP:</h2>
      <pre class=\"green\">$PRIVATE_IP</pre>
    </body>
    </html>" > index.html
  EOF
  vpc_security_group_ids = [aws_security_group.sg_ssh_http_https_anywhere.id, aws_security_group.efs_sg.id]
}

output "efs_dns" {
  value = aws_efs_file_system.efs_example.dns_name
}
output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.rds_instance.address
  sensitive   = true
}

output "public_ip" {
  value = aws_instance.test-web-instance[*].public_ip
}*/