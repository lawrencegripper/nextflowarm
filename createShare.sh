#!/bin/sh
#!/bin/bash
# $1 = Azure storage account name
# $2 = Azure storage account key
# $3 = Azure file share name

DEBIAN_FRONTEND="noninteractive"

echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
     sudo tee /etc/apt/sources.list.d/azure-cli.list 

apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
apt-get install apt-transport-https -y
apt-get update -y
apt-get install azure-cli -y

az storage share create --name $3 --quota 2048 --connection-string "DefaultEndpointsProtocol=https;EndpointSuffix=core.windows.net;AccountName=$1;AccountKey=$2" >> /tmp/sharecreate.log