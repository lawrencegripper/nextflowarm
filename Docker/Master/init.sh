#!/bin/sh
#!/bin/bash
# $1 = Azure storage account name
# $2 = Azure storage account key
# $3 = Azure file share name
# $4 = mountpoint path
# $5 = should run as nf node
# $6 = username of nextflow user


az storage share create --name $3 --quota 2048 --connection-string "DefaultEndpointsProtocol=https;EndpointSuffix=core.windows.net;AccountName=$1;AccountKey=$2" | tee -a /tmp/nfinstall.log

#Wait for the file share to be available. 
sleep 10

#Mount the share with symlink and fifo support: see https://wiki.samba.org/index.php/SMB3-Linux
mkdir -p $4/cifs | tee -a /tmp/nfinstall.log
# CIFS settings from Azure CloudShell container which uses .img approach. 
mount -t cifs //$1.file.core.windows.net/$3 $4/cifs -o vers=3.0,username=$1,password=$2,dir_mode=0777,file_mode=0777,mfsymlinks,sfu | tee -a /tmp/nfinstall.log

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

    echo "$NFS_SHAREPATH    $ALLOWEDSUBNET(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100)" > /etc/exports 

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



log "Setup Filesystem and Environment Variables" $LOGFILE

mkdir -p $NFS_SHAREPATH/work
chmod 777 $NFS_SHAREPATH/work
mkdir -p $NFS_SHAREPATH/assets
chmod 777 $NFS_SHAREPATH/assets

#Todo: This will repeatedly add the same env to the file. Fix that. 
#Configure nextflow environment vars    
echo export NXF_WORK=$NFS_SHAREPATH/work >> /etc/environment
echo export NXF_ASSETS=$NFS_SHAREPATH/assets >> /etc/environment
#Added for debugging
echo export NXF_AZ_USER=$6 >> /etc/environment
echo export NXF_AZ_LOGFILE=$LOGFILE >> /etc/environment
echo export NXF_AZ_CIFSPATH=$CIFS_SHAREPATH >> /etc/environment
echo export NXF_AZ_NFSPATH=$NFS_SHAREPATH >> /etc/environment

#Use asure epherical instance drive for tmp
mkdir -p /mnt/nftemp
echo export NXF_TEMP=/mnt/nftemp >> /etc/environment

#Allow user access to temporary drive
chmod -f 777 /mnt/nftemp #Todo: Review sec implications 

#Reload environment variables in this session. 
sed 's/^/export /' /etc/environment > /tmp/env.sh && source /tmp/env.sh