#!/bin/bash

set -e
echo "Installing docker"
sudo apt update

sudo apt-get install  curl apt-transport-https ca-certificates software-properties-common -y
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install docker-ce docker-compose -y
sudo systemctl enable docker
sudo systemctl start docker
sudo apt autoremove

mv /root/build-files /opt/catalog
cd /opt/catalog

docker compose build
docker compose up -d

echo "Docker installed"

echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf

hostnamectl set-hostname catalog
echo 'root:C4TL0bInsane2025$' | sudo chpasswd



ln -sf /dev/null /root/.bash_history

cd /root

cd /opt/catalog
rm -rf Dockerfile
rm -rf Dockerfile-Redis
rm -rf docker-compose.yml

rm -rf /root/build.sh

find /var/log -type f -exec sh -c "cat /dev/null > {}" \;


## Necessário para iniciar instancias na AWS
## Para desativar o acesso ao metadata das ec2 executar o comando aws cli aws ec2 modify-instance-metadata-options instance-id ${aws_instance.example.id} http-endpoint disabled
# systemctl disable cloud-init.service
# systemctl disable cloud-final.service
# systemctl disable cloud-config.service
# systemctl disable cloud-init-local.service
systemctl disable systemd-networkd-wait-online.service
systemctl set-default multi-user.target 
systemctl disable apparmor.service
## Failed to disable unit: Unit file systemd-timesyncd.service does not exist.
#systemctl disable systemd-timesyncd.service
systemctl disable systemd-resolved.service
systemctl disable ssh.service