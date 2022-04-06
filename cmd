export PATH=/home/feyintoluwa/Terraform/:$PATH
terraform init
terraform apply
terraform destroy
terraform plan
export PATH=/home/feyintoluwa/Terraform/:$PATH
sudo puttygen private_key.pem -o private_Key.ppk -O private
ssh-keygen -C ubuntu@ubuntu
# check the ubuntu ami and the ssh key to be os name
terraform plan -out=newplan
terraform plan -out=vpc_+
terraform import aws_network_acl.env_sec_rules acl-1ec0c476
terraform apply -target=file_name
#terraform var=ENV
aws ec2 create-default-vpc
