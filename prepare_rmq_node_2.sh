#!/bin/bash
#############################################################################################################
####################################prepare_rmq_node_2.sh####################################################
#############################################################################################################
### This script is used to automatically provision a RabbitMQ cluster. This script is meant to be run     ###
### second, and will provision the second node and connect to the cluster. This script will do the        ### 
### following:                                                                                            ###
###                                                                                                       ###
###  - Provision an LVM volume on an attached Disk                                                        ###
###  - Automatically mount disk with fstab entry                                                          ###
###  - Specify a static networking configuration                                                          ###
###  - Upgrade packages and install couchbase                                                             ###
###  - Modify the earling encryption cookie                                                               ###
###  - Disable the firewall                                                                               ###
###  - Set a higher value for linux ulimit                                                                ###
###  - Initialize the RMQ node                                                                            ###
###  - Join the node to the cluster                                                                       ###
#############################################################################################################
#############################################################################################################

#Create LVM partition on a Disk and format it as ext4.
echo 'start=2048, type=8E' | sudo sfdisk /dev/sdc
sudo pvcreate /dev/sdc1
sudo vgcreate rabbitmq /dev/sdc1
sudo lvcreate -l 100%FREE rabbitmq
sudo mkfs.ext4 /dev/rabbitmq/lvol0

#Automatically mount partition on system boot.
sudo mkdir /rmq/
echo '/dev/rabbitmq/lvol0      /rmq      ext4      defaults,nofail      0      0' | sudo tee --append /etc/fstab > /dev/null

#Configure Static Networking
sudo sed -i 's/dhcp/static/' /etc/network/interfaces.d/50-cloud-init.cfg
echo 'address >IPADDR2<' | sudo tee --append /etc/network/interfaces.d/50-cloud-init.cfg > /dev/null
echo 'netmask >SUBNET<' | sudo tee --append /etc/network/interfaces.d/50-cloud-init.cfg > /dev/null
echo 'gateway >GATEWAY<' | sudo tee --append /etc/network/interfaces.d/50-cloud-init.cfg > /dev/null
echo 'dns-nameservers >NAMESERVER<' | sudo tee --append /etc/network/interfaces.d/50-cloud-init.cfg > /dev/null
echo 'dns-search >SEARCH DOMAIN<' | sudo tee --append /etc/network/interfaces.d/50-cloud-init.cfg > /dev/null
echo '>IPADDR<   >HOSTNAME<       >HOSTNAME.FQDN<' | sudo tee --append /etc/hosts > /dev/null
echo '>IPADDR-NODE2<   >HOSTNAME-NODE2<       >HOSTNAME-NODE2.FQDN<' | sudo tee --append /etc/hosts > /dev/null
sudo systemctl restart networking.service
sudo hostnamectl set-hostname >HOSTNAME-NODE2<

#Add repos, accept repo key, upgrade packages and install dependencies.
wget -O- https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | sudo apt-key add -
echo 'deb http://www.rabbitmq.com/debian/ testing main' | sudo tee /etc/apt/sources.list.d/rabbitmq.list
wget -O- https://packages.erlang-solutions.com/debian/erlang_solutions.asc | sudo apt-key add -
echo 'deb https://packages.erlang-solutions.com/debian wheezy contrib' | sudo tee /etc/apt/sources.list.d/esl.list

sudo apt-get update
sudo apt-get upgrade -y < "/dev/null"
sudo apt-get install -y rabbitmq-server socat esl-erlang < "/dev/null"
sudo sed -i 's/#ulimit\ -n\ 1024/ulimit\ -S\ -n\ 4096/' /etc/default/rabbitmq-server
sudo ufw disable

#Set owner of rabbitmq directory to rabbitmq.
sudo mount -a
sleep 5
sudo chown -R rabbitmq:rabbitmq /rmq

#Move database to external disk
sudo rabbitmqctl stop_app
sudo cp -r /var/lib/rabbitmq/mnesia /rmq/mnesia
sudo chown -R rabbitmq:rabbitmq /rmq/mnesia
sudo chmod 766 /rmq/mnesia
sudo touch /etc/rabbitmq/rabbitmq-env.conf
echo 'CONFIG_FILE=/etc/rabbitmq' | sudo tee --append /etc/rabbitmq/rabbitmq-env.conf
echo 'RABBITMQ_MNESIA_BASE=/rmq/mnesia/mnesia' | sudo tee --append /etc/rabbitmq/rabbitmq-env.conf
sudo chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq-env.conf
sudo systemctl restart rabbitmq-server
sleep 5

#Update erlang cookie
sudo rabbitmqctl stop_app
sudo systemctl stop rabbitmq-server
sudo chmod 777 /var/lib/rabbitmq/.erlang.cookie
sudo echo '>ERLANGCOOKIE<' > /var/lib/rabbitmq/.erlang.cookie
sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie
sudo systemctl start rabbitmq-server
sleep 5

#Cluster with node 1
sudo rabbitmqctl stop_app
sleep 5
sudo rabbitmqctl join_cluster rabbit@>HOSTNAME<
sleep 5
sudo rabbitmqctl start_app
sleep 5

#Configure RMQ Cluster
sudo rabbitmq-plugins enable rabbitmq_management
sudo rabbitmqctl add_user >USERNAME< >PASSWORD<
sudo rabbitmqctl set_permissions -p / >USERNAME< ".*" ".*" ".*"
sudo rabbitmqctl set_user_tags >USERNAME< administrator
sudo rabbitmqctl set_cluster_name >CLUSTERNAME<

#Exit if script was executed through an ssh session.
exit 0
