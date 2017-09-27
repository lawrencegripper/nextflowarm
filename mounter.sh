#!/bin/sh
#!/bin/bash
# $1 = Azure storage account name
# $2 = Azure storage account key
# $3 = Azure file share name
# $4 = mountpoint path

#Install CIFS and JQ (used by this script)
apt-get -y update | tee /tmp/nfinstall.log
apt-get install cifs-utils jq -y | tee -a /tmp/nfinstall.log


mkdir -p $4 | tee -a /tmp/nfinstall.log
mount -t cifs //$1.file.core.windows.net/$3 $4 -o vers=3.0,username=$1,password=$2,dir_mode=0777,file_mode=0777,mfsymlinks | tee -a /tmp/nfinstall.log

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

#Install nextflow
curl -s https://get.nextflow.io | bash | tee -a $LOGFILE

#Run nextflow under log dir to provide easy access to logs
NFDIR=$(pwd)
cd $LOGFOLDER
$NFDIR/nextflow node -bg -cluster.join path:/media/shared/cluster