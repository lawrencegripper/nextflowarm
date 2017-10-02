#!/bin/sh
#!/bin/bash
# $1 = Azure storage account name
# $2 = Azure storage account key
# $3 = Azure file share name
# $4 = mountpoint path
# $5 = should run as nf node

DEBIAN_FRONTEND="noninteractive"

#Install CIFS and JQ (used by this script)
apt-get -y update | tee /tmp/nfinstall.log
apt-get install cifs-utils jq -y | tee -a /tmp/nfinstall.log


#Create azure share if it doesn't already exist
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
     sudo tee /etc/apt/sources.list.d/azure-cli.list 

apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
apt-get install apt-transport-https -y
apt-get update -y
apt-get install azure-cli -y

az storage share create --name $3 --quota 2048 --connection-string "DefaultEndpointsProtocol=https;EndpointSuffix=core.windows.net;AccountName=$1;AccountKey=$2" | tee -a /tmp/nfinstall.log

#Mount the share with symlink and fifo support: see https://wiki.samba.org/index.php/SMB3-Linux
mkdir -p $4/cifs | tee -a /tmp/nfinstall.log
mount -t cifs //$1.file.core.windows.net/$3 $4/cifs -o vers=3.0,username=$1,password=$2,dir_mode=0777,file_mode=0777,mfsymlinks,sfu | tee -a /tmp/nfinstall.log

###############
# Workaround for Azure Files Posix support
#   This attempts to create a .img file, to act as shared storage, and stores it on Azure Files share. 
#   This enables full posix support for fifo, symlinks etc. See https://github.com/lawrencegripper/nextflowarm/issues/5
#   Create the file and format on the master node, other nodes wait for it to complete
###############
if [ "$5" != true ]; then #If we're the master node create the img file
then 
    touch .creating
    dd if=/dev/zero of=share.img bs=1M count=50000 | tee -a /tmp/nfinstall.log
    mkfs ext3 -F $4/cifs/shared.img | tee -a /tmp/nfinstall.log
    touch .done
fi

while [ ! -f $4/cifs/.done ]
do
  sleep 5
done

mkdir -p $4/img | tee -a /tmp/nfinstall.log
mount -o loop,rw,sync $4/cifs/shared.img $4/img | tee -a /tmp/nfinstall.log
chmod 777 $4/img | tee -a /tmp/nfinstall.log

###############
# end
###############

#Write instance details into share /cluster for debugging
METADATA=$(curl -H Metadata:true http://169.254.169.254/metadata/instance?api-version=2017-04-02)
NODENAME=$(echo $METADATA | jq -r '.compute.name')

#Create a log folder for each node
mkdir -p $4/logs/$NODENAME | tee -a /tmp/nfinstall.log

#Copy logs used so far
cp /tmp/nfinstall.log $4/logs/$NODENAME/
LOGFOLDER=$4/logs/$NODENAME/
LOGFILE=$4/logs/$NODENAME/nfinstall.log

#Track the metadata for the node for debugging
echo $METADATA > $4/logs/$NODENAME/node.metadata 

#Install java
apt-get install openjdk-8-jdk -y | tee -a $LOGFILE

#Allow user access to temporary drive
chmod -f 777 /mnt #Todo: Review sec implications 

#Todo: This will repeatedly add the same env to the file. Fix that. 
#Configure nextflow environment vars    
echo export NXF_ASSETS=$4/assets >> /etc/environment
echo export NXF_WORK=$4/work >> /etc/environment
#Use asure epherical instance drive for tmp
echo export NXF_TEMP=/mnt >> /etc/environment

#Reload environment variables in this session. 
sed 's/^/export /' /etc/environment > /tmp/env.sh && source /tmp/env.sh

#Install nextflow
curl -s https://get.nextflow.io | bash | tee -a $LOGFILE

#Copy the binary to the path to be accessed by users
cp ./nextflow /usr/local/bin
chmod -f 777 /usr/local/bin/nextflow #Todo: Review sec implications 


#If we're a node run the daemon
if [ "$5" = true ]; then 

#Run nextflow under log dir to provide easy access to logs
echo "Starting cluster nextflow cluster node" | tee -a $LOGFILE
cd $LOGFOLDER
/usr/local/bin/nextflow node -bg -cluster.join path:$4/cluster
echo "Cluster node started" | tee -a $LOGFILE

fi