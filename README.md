# devops-project
## Tools involved: Terraform, Ansible, Git
## Objectives: 
- Use Terraform to provision an EC2 instance in a new created VPC and with appropriate security groups attached to allow ssh access in AWS
- Terraform to call Ansible to install the following applications on the instance
   * Java openjdk
   * Jenkins
   * Python

## Setup:
* Installed Terraform on my local machine
* Described what I want to provision using Terraform code
    * Network components
    * Upload a key pair
    * EC2 instance
    * Provisioner
* Included a local-exec provisioner for terraform to call Ansible
* Installed Ansible on my local machine
* Created a playbook to install Java, Jenkins and Python
