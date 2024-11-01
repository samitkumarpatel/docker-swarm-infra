# docker-swarm-infra

### Reference
* [Installation](https://docs.docker.com/engine/security/rootless/#install)

* [Expose docker api via tcp](https://docs.docker.com/engine/security/rootless/#expose-docker-api-socket-through-tcp)


### How to Use this repo ?

The goal is to provision more then one ec2 on private subnet via an jump host.

This has been achieved via [ssh tunneling](https://www.ssh.com/academy/ssh/tunneling)

```sh
# Terraform init , plan and apply
terraform init
terraform validate
terraform plan
terraform apply --auto-approve

# Check how does inventory file looks like
ansible-inventory -i ansible/inventory.yml --list --vars

# Make ready ssh key to be used for ansible
terraform output -raw ssh_key >> id_rsa.pem
chmod 400 id_rsa.pem

# Ping it with ansible
ansible -i inventory.yml all -m ping
```

> If the ping is success to all the host, then the way you want , you can decorate ansible-playbook and run via ansible! 


### Docker swarm access control, So that CI or admin can use it from remote without ssh


```sh
sudo nano /lib/systemd/system/docker.service

# Search ExecStart on that file and edit like below

ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock

#OR 

ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock -H tcp://0.0.0.0:2376

#OR

ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2376 --tlsverify --tlscacert=/etc/docker/ca.pem --tlscert=/etc/docker/server-cert.pem --tlskey=/etc/docker/server-key.pem

# Then restart the daemon

sudo systemctl daemon-reload
sudo systemctl restart docker

```

### Create docker context , so that you can connect from your local machine and deploy stack and services

```sh
# Example
docker context create my-context --description "some description" --docker "host=tcp://myserver:2376,ca=~/ca-file,cert=~/cert-file,key=~/key-file" 

# OR

docker context create my-remote-context --docker "host=tcp://<REMOTE_HOST_IP>:2375"

```

## Playground

If you want a local docker swarm multi host env to try swarm use `docker-machine`

### Unix

```sh
base=https://github.com/docker/machine/releases/download/v0.16.2 &&
curl -L $base/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine &&
sudo install /tmp/docker-machine /usr/local/bin/docker-machine

```

### ansible module to parse terrform state file for dynamic inventory

```sh
ansible-galaxy collection install cloud.terraform
```

#### overview inventory

```sh
ansible-inventory -i ansible/inventory.yml --list --vars
```

#### playbook

```sh
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml -e docker_registry_username=amitzrepo -e docker_registry_password=token-xyz
```