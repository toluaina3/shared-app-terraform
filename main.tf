module "vpc" {
  source           = "github.com/Bigbotteam/aws-terraform-modules.git?ref=aws-module-vpc"
  vpc-cidr-block   = "192.168.1.0/24"
  tag-name         = "test-vpc"
}

# attach internet gateway to the vpc for public subnet internet connection
module "internet-gateway" {
  source      = "github.com/Bigbotteam/aws-terraform-modules.git?ref=aws-module-internet-gateway"
  ig-vpc-id   = module.vpc.vpc-network-id
  tag-name    = "test-internet-gateway"
}

# public subnet facing the internet
module "public-subnet" {
  source                  = "github.com/Bigbotteam/aws-terraform-modules.git?ref=aws-modules-subnets"
  subnet-az               = "eu-west-2a"
  subnet-route-cidr       = "192.168.1.0/27"
  vpc-network             = module.vpc.vpc-network-id
  map-public-ip           = true
  tag-name                = "public-subnet-1"
}


# the private subnet where the EC2 instance will be deployed
module "private-subnet" {
  source                  = "./.terraform/modules/public-subnet"
  subnet-az               = "eu-west-2b"
  subnet-route-cidr       = "192.168.1.96/27"
  vpc-network             = module.vpc.vpc-network-id
  map-public-ip           = false
  tag-name                = "private-subnet-2"

}

# nat gateway is in a public subnet, route private subnet traffic to the internet
resource "aws_nat_gateway" "private-nat-gateway" {
  subnet_id = module.public-subnet.subnet-id
  allocation_id        = ""
  tags                 = {
    Name               = "nat-gateway-private-subnet"
        }
}


# route for the Ec2 instance to reach the internet from the private subnet
module "route-table-private-subnets" {
  source             = "github.com/Bigbotteam/aws-terraform-modules.git?ref=aws-module-route-table-private"
  route-cidr         = "0.0.0.0/0"
  nat_gateway_id     = aws_nat_gateway.private-nat-gateway.id
  vpc-network        = module.vpc.vpc-network-id
  tag-name           = "route-table-private-subnets"
}

# associate the subnet to the route
module "route-assoc-private-subnets" {
  source              = "github.com/Bigbotteam/aws-terraform-modules.git?ref=aws-module-route-association"
  route-table-id      = module.route-table-private-subnets.route-table-id
  subnet-id           = module.private-subnet.subnet-id
}

# create the security group for the ec2 instance
module "ec2-sec-group-http" {
  source          = "cloudposse/security-group/aws"
  vpc_id          = module.vpc.vpc-network-id
   # Here we add an attribute to give the security group a unique name.
  attributes      = ["ec2-sec-group"]
  # Allow unlimited egress
  allow_all_egress = true
  rules = [
    {
      key         = "ssh"
      type        = "ingress"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      # accept connection from vpc resources only
      cidr_blocks = ["0.0.0.0/0"]
      self        = null
      description = "Allow SSH from anywhere"
    },
    {
      key         = "HTTP"
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      self        = null
      description = "Allow HTTP from inside the security group"
    },
    {
      key         = "HTTPS"
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      self        = null
      description = "Allow HTTPS from inside the security group"
    }
  ]
}

# the public key to be use for the Ec2 instance
# the key is passed in through the variable
resource "aws_key_pair" "ec2-public-key" {
   key_name   = "ec2-key"
   public_key = var.EC2_PUBLIC_KEY
}


# set up the EC2 instance and deploy the Node.Js app
resource "aws_instance" "nginx-server" {
  ami                         = lookup(var.AMIS, var.AWS_REGION)
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.ec2-public-key.key_name
  vpc_security_group_ids      = [module.ec2-sec-group-http.id]
  subnet_id                   = module.public-subnet.subnet-id

  # copy the entry file into the server
  provisioner "file" {
    source                    = "entry.sh"
    destination               = "/tmp/entry.sh"
  }
  # copy the ansible directory to the server
  provisioner "file" {
    source                   = "ngnix-task"
    destination              = "home/"
    # remote command on instance
  }
  tags                       = {
    "Name": "nginx-server",
    "Environment": "development"
  }
  # run the script to provision the ngnix server and automate processes.
  provisioner "remote-exec" {
    inline                  = [
      "cd ~/home/nginx",
      "sudo apt-get update -y",
      "pip install ansible",
      "cd //",
      "cd /tmp",
      "sudo chmod +x entry.sh",
      "./entry.sh",
      "cd //",
      "cp /tmp/entry.sh ~/home/tasks"
    ]
  }
  # remote command on instance
  connection {
    # connect to resource and instance
    type        = "ssh"
    user        = var.EC2_USERNAME
    private_key = file(var.EC2_PRIVATE_KEY)
    host        = self.public_ip
  }
}

# set up the EC2 instance and deploy the Node.Js app
resource "aws_instance" "backend" {
  ami                         = lookup(var.AMIS, var.AWS_REGION)
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.ec2-public-key.key_name
  vpc_security_group_ids      = [module.ec2-sec-group-http.id]
  subnet_id                   = module.private-subnet.subnet-id

  # copy the entry file into the server
  provisioner "file" {
    source                    = "entry.sh"
    destination               = "/tmp/entry.sh"
  }
  # copy the ansible directory to the server
  provisioner "file" {
    source                   = "ansible"
    destination              = "home/"
    # remote command on instance
  }
  tags                       = {
    "Name": "shared-apps",
    "Environment": "development"
  }
  # run the script to provision the server and automate processes.
  provisioner "remote-exec" {
    inline                  = [
      "cd ~/home/tasks",
      "sudo apt-get update -y",
      "pip install ansible",
      "sudo apt-get install npm",
      "cd //",
      "cd /tmp",
      "sudo chmod +x entry.sh",
      "./entry.sh",
      "cd //",
      "cp /tmp/entry.sh ~/home/tasks"
    ]
  }
  # remote command on instance
  connection {
    # connect to resource and instance
    type        = "ssh"
    user        = var.EC2_USERNAME
    private_key = file(var.EC2_PRIVATE_KEY)
    host        = self.public_ip
  }
}

output "nginx-public-ip" {
  value = aws_instance.nginx-server.public_ip
}