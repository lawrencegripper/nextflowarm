#!/bin/sh
#!/bin/bash
# $1 = Azure storage account name
# $2 = Azure storage account key
# $3 = Azure file share name
# $4 = mountpoint path
# $5 = should run as nf node
# $6 = username of nextflow user

log () {
    echo "-------------------------" | tee -a $2
    date -Is | tee -a $2
    echo $1 | tee -a $2
    echo "-------------------------" | tee -a $2    
}

#Install CIFS and JQ (used by this script)
log "Installing CIFS and JQ" /tmp/nfinstall.log 
apt-get -y update | tee /tmp/nfinstall.log
apt-get install cifs-utils -y | tee -a /tmp/nfinstall.log

#Create azure share if it doesn't already exist
log "Installing AzureCLI and Mounting Azure Files Share" /tmp/nfinstall.log 
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
     sudo tee /etc/apt/sources.list.d/azure-cli.list 

apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893 | tee -a /tmp/nfinstall.log
apt-get -y update | tee /tmp/nfinstall.log
apt-get install apt-transport-https -y | tee -a /tmp/nfinstall.log
apt-get install azure-cli -y | tee -a /tmp/nfinstall.log

az storage share create --name $3 --quota 2048 --connection-string "DefaultEndpointsProtocol=https;EndpointSuffix=core.windows.net;AccountName=$1;AccountKey=$2" | tee -a /tmp/nfinstall.log

#Wait for the file share to be available. 
sleep 10

#Mount the share with symlink and fifo support: see https://wiki.samba.org/index.php/SMB3-Linux
mkdir -p $4/cifs | tee -a /tmp/nfinstall.log
# CIFS settings from Azure CloudShell container which uses .img approach. 
mount -t cifs //$1.file.core.windows.net/$3 $4/cifs -o vers=3.0,username=$1,password=$2,dir_mode=0777,file_mode=0777,mfsymlinks,sfu | tee -a /tmp/nfinstall.log
CIFS_SHAREPATH=$4/cifs

###############
# Workaround for Azure Files Posix support
#   This attempts to create a .img file, to act as shared storage, and stores it on Azure Files share. 
#   This enables full posix support for fifo, symlinks etc. See https://github.com/lawrencegripper/nextflowarm/issues/5
#   Create the file and format on the master node, other nodes wait for it to complete
###############

#Variables
#WARNING: NFS share currently on temporary drive. Will not persist between boots. 
NFS_SHAREPATH=$4/nfs #Location NFS share will be mounted at

mkdir -p $NFS_SHAREPATH | tee -a /tmp/nfinstall.log
if [ "$5" != true ]; then #If we're the master node create the img file 
    log "MASTER: Creating NFS share" /tmp/nfinstall.log 

    #Variables
    ALLOWEDSUBNET=10.0.0.0/24

    #Install CIFS and JQ (used by this script)
    log "Installing NFS Server" /tmp/nfinstall.log 
    apt-get install nfs-kernel-server -y | tee -a /tmp/nfinstall.log

    #TODO: Review permissions and security
    mkdir $NFS_SHAREPATH | tee -a /tmp/nfinstall.log
    chown nobody:nogroup $NFS_SHAREPATH | tee -a /tmp/nfinstall.log
    chmod 777 $NFS_SHAREPATH | tee -a /tmp/nfinstall.log

    echo "$NFS_SHAREPATH    $ALLOWEDSUBNET(rw,sync,no_subtree_check)" > /etc/exports 

    systemctl restart nfs-kernel-server | tee -a /tmp/nfinstall.log

    touch $CIFS_SHAREPATH/.done_creating_nfs_share | tee -a /tmp/nfinstall.log
fi

while [ ! -f $CIFS_SHAREPATH/.done_creating_nfs_share ]
do
    log "NODE: Waiting for NFS share to be created" /tmp/nfinstall.log 
    sleep 5
done

if [ "$5" = true ]; then
    log "NODE: Install NFS client tools" /tmp/nfinstall.log 
    apt-get install nfs-kernel-server -y | tee -a /tmp/nfinstall.log

    log "NODE: Mounting NFS share" /tmp/nfinstall.log 
    mkdir -p $NFS_SHAREPATH | tee -a /tmp/nfinstall.log
    mount jumpboxvm:$NFS_SHAREPATH $NFS_SHAREPATH | tee -a /tmp/nfinstall.log
    chmod 777 $NFS_SHAREPATH | tee -a /tmp/nfinstall.log
fi

###############
# end
###############

log "Get machine metadata and copy logs to share"

apt-get install jq -y | tee -a /tmp/nfinstall.log
#Write instance details into share /cluster for debugging
METADATA=$(curl -H Metadata:true http://169.254.169.254/metadata/instance?api-version=2017-04-02)
NODENAME=$(echo $METADATA | jq -r '.compute.name')

#Create a log folder for each node
mkdir -p $CIFS_SHAREPATH/logs/$NODENAME | tee -a /tmp/nfinstall.log

#Copy logs used so far
cp /tmp/nfinstall.log $CIFS_SHAREPATH/logs/$NODENAME/
LOGFOLDER=$CIFS_SHAREPATH/logs/$NODENAME/
LOGFILE=$CIFS_SHAREPATH/logs/$NODENAME/nfinstall.log

#Track the metadata for the node for debugging
echo $METADATA > $CIFS_SHAREPATH/logs/$NODENAME/node.metadata 

#Install java
log "Installing JAVA" $LOGFILE
apt-get install openjdk-8-jdk -y | tee -a $LOGFILE

log "Install Docker" $LOGFILE
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - | tee -a $LOGFILE
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee -a $LOGFILE
apt-get update -y | tee -a $LOGFILE
apt-get install -y docker-ce | tee -a $LOGFILE
#Add the nextflow user to the docker group. 
usermod -aG docker $6 | tee -a $LOGFILE


log "Setup Filesystem and Environment Variables" $LOGFILE

mkdir -p $NFS_SHAREPATH/work
chmod 777 $NFS_SHAREPATH/work
mkdir -p $NFS_SHAREPATH/assets
chmod 777 $NFS_SHAREPATH/assets

#Todo: This will repeatedly add the same env to the file. Fix that. 
#Configure nextflow environment vars    
echo export NXF_WORK=$NFS_SHAREPATH/work >> /etc/environment
echo export NXF_ASSETS=$NFS_SHAREPATH/assets >> /etc/environment

#Use asure epherical instance drive for tmp
mkdir -p /mnt/nftemp
echo export NXF_TEMP=/mnt/nftemp >> /etc/environment

#Allow user access to temporary drive
chmod -f 777 /mnt/nftemp #Todo: Review sec implications 

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

#Run nextflow under log dir to provide easy access to logs. Run as nextflow user to ensure correct permissions.
log "NODE: Starting cluster nextflow cluster node" $LOGFILE
sudo -H -u $6 bash -c "cd $LOGFOLDER && /usr/local/bin/nextflow node -bg -cluster.join path:$CIFS_SHAREPATH/cluster"
log "NODE: Cluster node started" $LOGFILE

fi
