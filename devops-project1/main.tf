terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
  # access_key = var.access_key
  # secret_key = var.secret_key
  # token = var.token
}

locals {
  private_key_path = "~/.ssh/terraform-key"
}

# new vpc 
resource "aws_vpc" "ansible" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name = "${var.prefix}-vpc-${var.region}"
    environment = var.environment
  }
}

resource "aws_subnet" "ansible" {
  vpc_id     = aws_vpc.ansible.id
  cidr_block = var.subnet_prefix

  tags = {
    name = "${var.prefix}-subnet"
  }
}

resource "aws_security_group" "ansible" {
  name = "${var.prefix}-security-group"

  vpc_id = aws_vpc.ansible.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.prefix}-security-group"
  }
}

resource "aws_internet_gateway" "ansible" {
  vpc_id = aws_vpc.ansible.id

  tags = {
    Name = "${var.prefix}-internet-gateway"
  }
}

resource "aws_route_table" "ansible" {
  vpc_id = aws_vpc.ansible.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ansible.id
  }
}

resource "aws_route_table_association" "ansible" {
  subnet_id      = aws_subnet.ansible.id
  route_table_id = aws_route_table.ansible.id
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "deployer" {
  key_name   = "terraform-key"
  public_key = var.public_key
}

resource "aws_eip" "ansible" {
  instance = aws_instance.web.id
  vpc      = true
}

resource "aws_eip_association" "ansible" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.ansible.id
}

# create an EC2 instance
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.ansible.id
  vpc_security_group_ids      = [aws_security_group.ansible.id]
  key_name = "terraform-key"
  tags = {
    Name = "Ansible + Terraform "
    }

  provisioner "remote-exec" {
   inline = ["echo 'wait until SSH is read'"]
   connection {
     type    = "ssh"
     user    = var.user
     private_key = file(local.private_key_path)
     host        = aws_instance.web.public_ip
    }
   }

#kick off ansible to install the application
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.user} -i '${aws_instance.web.public_ip},' --private-key ${local.private_key_path} /etc/ansible/playbook.yml"
    # command = "ansible-playbook -u ubuntu -i /Users/fangli.zhan1/workspace/devops_project/devops_project1/hosts, /etc/ansible/playbook.yml"
   }
  }

data "template_file" "hosts" {
  template = "${file("/Users/fangli.zhan1/workspace/devops-project/devops-project1/hosts.tmpl")}"
  vars = {
      public_ip = aws_instance.web.public_ip
  }
}
resource "local_file" "hosts" {
  content = data.template_file.hosts.rendered
  filename = "/Users/fangli.zhan1/workspace/devops-project/devops-project1/hosts"
}


output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "instance_eip" {
  value = aws_eip.ansible.public_ip
}
