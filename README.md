**Infrastructure as a code using Terraform**

Terraform is used to set up AWS network components VPC, internet gateway, subnets, route-table, security-groups
and EC2 instance.

Nginx server is used as a reverse proxy in connecting to the Node.JS application server.

The Nginx server is deployed to a public subnet and receives request from the internet and sends request to the
application server which is deployed in the private subnet.

The customer can log in to the AWS console to retrieve the public IP of the nginx server for connection to the 
application server.

Public IP of the server can also be known through the output defined for the nginx-server instance.