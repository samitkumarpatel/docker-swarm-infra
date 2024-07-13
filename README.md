# docker-swarm-infra

### How to Use ?

The goal is to provision some private ec2 via an jump host.

This has been achieved via [ssh tunneling](https://www.ssh.com/academy/ssh/tunneling)

```sh
# Terraform init , plan and apply
terraform init
terraform validate
terraform plan
terraform apply --auto-approve

# Check how does inventory file looks like
ansible-inventory -i inventory.yml --list --vars

# Make ready ssh key to be used for ansible
terraform output -raw ssh_key >> id_rsa.pem
chmod 400 id_rsa.pem

# Ping it with ansible
ansible -i inventory.yml all -m ping
```
> If the ping is success to all the host, then the way you want , you can decorate ansible-playbook and run via ansible! 


### Create docker context , so that you can connect from your local machine and deploy stack and services

```sh
docker context create my-context --description "some description" --docker "host=tcp://myserver:2376,ca=~/ca-file,cert=~/cert-file,key=~/key-file" 
```

