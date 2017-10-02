log () {
    echo "-------------------------" | tee -a $2
    date -Is | tee -a $2
    echo $1 | tee -a $2
    echo "-------------------------" | tee -a $2    
}

DEBIAN_FRONTEND="noninteractive"

#Variables
ALLOWEDSUBNET=10.0.0.0/24

#Install CIFS and JQ (used by this script)
log "Installing NFS Server" /tmp/nfinstall.log 
apt-get -y update | tee /tmp/nfinstall.log
apt-get install nfs-kernel-server jq -y | tee -a /tmp/nfinstall.log

SHAREPATH=/mnt/sharesource

mkdir $SHAREPATH

chown nobody:nogroup $SHAREPATH

echo "$SHAREPATH    $ALLOWEDSUBNET(rw,sync,no_subtree_check)" > /etc/exports 

systemctl restart nfs-kernel-server