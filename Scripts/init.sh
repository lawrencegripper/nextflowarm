#!/bin/sh
#!/bin/bash
# $1 = Azure storage account name
# $2 = Azure storage account key
# $3 = Azure file share name
# $4 = mountpoint path
# $5 = should run as nf node

log () {
    echo "-------------------------" | tee -a $2
    date -Is | tee -a /tmp/nfinstall.log
    echo $1 | tee -a /tmp/nfinstall.log
    echo "-------------------------" | tee -a $2    
}

DEBIAN_FRONTEND="noninteractive"

#Install CIFS and JQ (used by this script)
log "Installing CIFS and JQ" /tmp/nfinstall.log 
apt-get -y update | tee /tmp/nfinstall.log
apt-get install cifs-utils jq -y | tee -a /tmp/nfinstall.log



#Create azure share if it doesn't already exist
log "Installing AzureCLI and Mounting Azure Files Share" /tmp/nfinstall.log 
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
     sudo tee /etc/apt/sources.list.d/azure-cli.list 

apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
apt-get install apt-transport-https -y
apt-get update -y
apt-get install azure-cli -y

az storage share create --name $3 --quota 2048 --connection-string "DefaultEndpointsProtocol=https;EndpointSuffix=core.windows.net;AccountName=$1;AccountKey=$2" | tee -a /tmp/nfinstall.log

#Mount the share with symlink and fifo support: see https://wiki.samba.org/index.php/SMB3-Linux
mkdir -p $4/cifs | tee -a /tmp/nfinstall.log
# CIFS settings from Azure CloudShell container which uses .img approach. 
mount -t cifs //$1.file.core.windows.net/$3 $4/cifs -o vers=2.1,username=$1,password=$2,sec=ntlmssp,cache=strict,domain=X,uid=0,noforceuid,gid=0,noforcegid,file_mode=0777,dir_mode=0777,nounix,serverino,mapposix,rsize=1048576,wsize=1048576,echo_interval=60,actimeo=1 | tee -a /tmp/nfinstall.log
SHAREPATH=$4/cifs

###############
# Workaround for Azure Files Posix support
#   This attempts to create a .img file, to act as shared storage, and stores it on Azure Files share. 
#   This enables full posix support for fifo, symlinks etc. See https://github.com/lawrencegripper/nextflowarm/issues/5
#   Create the file and format on the master node, other nodes wait for it to complete
###############
mkdir -p $SHAREPATH/imgs/ | tee -a /tmp/nfinstall.log
SHAREIMGFILE=$SHAREPATH/imgs/share.img
if [ "$5" != true ]; then #If we're the master node create the img file 
    log "MASTER: Creating .IMG file for shared partition in Azure Files Share" /tmp/nfinstall.log 

    touch $SHAREPATH/.creating
    dd if=/dev/zero of=$SHAREIMGFILE bs=1 count=0 seek=10G | tee -a /tmp/nfinstall.log
    mkfs ext2 -F $SHAREIMGFILE | tee -a /tmp/nfinstall.log

    touch $SHAREPATH/.done
fi

while [ ! -f $SHAREPATH/.done ]
do
    log "NODE: Waiting for .IMG File to be created" /tmp/nfinstall.log 
    sleep 5
done

log "Mounting .IMG file" /tmp/nfinstall.log 
mkdir -p $4/img | tee -a /tmp/nfinstall.log
mount -o loop,rw,sync $SHAREIMGFILE $4/img | tee -a /tmp/nfinstall.log
chmod 777 $4/img | tee -a /tmp/nfinstall.log
SHAREIMGMOUNT=$4/img

###############
# end
###############

#Write instance details into share /cluster for debugging
METADATA=$(curl -H Metadata:true http://169.254.169.254/metadata/instance?api-version=2017-04-02)
NODENAME=$(echo $METADATA | jq -r '.compute.name')

#Create a log folder for each node
mkdir -p $SHAREPATH/logs/$NODENAME | tee -a /tmp/nfinstall.log

#Copy logs used so far
cp /tmp/nfinstall.log $SHAREPATH/logs/$NODENAME/
LOGFOLDER=$SHAREPATH/logs/$NODENAME/
LOGFILE=$SHAREPATH/logs/$NODENAME/nfinstall.log

#Track the metadata for the node for debugging
echo $METADATA > $SHAREPATH/logs/$NODENAME/node.metadata 

#Install java
log "Installing JAVA" $LOGFILE
apt-get install openjdk-8-jdk -y | tee -a $LOGFILE

log "Setup Filesystem and Environment Variables" $LOGFILE
#Allow user access to temporary drive
chmod -f 777 /mnt #Todo: Review sec implications 

#Todo: This will repeatedly add the same env to the file. Fix that. 
#Configure nextflow environment vars    
echo export NXF_ASSETS=$SHAREIMGMOUNT/assets >> /etc/environment
echo export NXF_WORK=$SHAREIMGMOUNT/work >> /etc/environment
#Use asure epherical instance drive for tmp
echo export NXF_TEMP=/mnt >> /etc/environment

#Reload environment variables in this session. 
sed 's/^/export /' /etc/environment > /tmp/env.sh && source /tmp/env.sh

#Install nextflow
log "Installing nextflow" $LOGFILE
curl -s https://get.nextflow.io | bash | tee -a $LOGFILE

#Copy the binary to the path to be accessed by users
cp ./nextflow /usr/local/bin
chmod -f 777 /usr/local/bin/nextflow #Todo: Review sec implications 

log "Done with Install. "

#If we're a node run the daemon
if [ "$5" = true ]; then 

#Run nextflow under log dir to provide easy access to logs
log "NODE: Starting cluster nextflow cluster node" $LOGFILE
cd $LOGFOLDER
/usr/local/bin/nextflow node -bg -cluster.join path:$SHAREPATH/cluster
log "NODE: Cluster node started" $LOGFILE

fi