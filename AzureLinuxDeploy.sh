#!/bin/bash -x

backupGatewayPackage=$1
companyAuthCode=$2
data_disk_size=$3
ddb_disk_size=$4

install_plus_log_disk_size=15
install_size=10
log_size=4.9

echo "Running configuration scripts..."
sudo systemctl stop firewalld.service
sudo systemctl disable firewalld.service
sleep 30

date
lsblk

# The ddb and data disks are determined based on the input data_disk_size and ddb_disk_size.
# By doing a grep on lsblk with the input sizes our data disks will be determined.
ddb_disk_name=$(lsblk -o NAME,SIZE | grep $ddb_disk_size"G" | awk '{print $1}')
echo "DDB disk name: $ddb_disk_name"
data_disk_name=$(lsblk -o NAME,SIZE | grep $data_disk_size"G" | awk '{print $1}')
echo "Install disk name: $data_disk_name"

echo "Check and wait for device /dev/$ddb_disk_name"
while [ ! -d /sys/block/$ddb_disk_name ]; do sleep 5; done
echo "Check and wait for device /dev/$data_disk_name"
while [ ! -d /sys/block/$data_disk_name ]; do sleep 5; done
echo "Wait for /dev/$ddb_disk_name running state"
while [ "running" != "$(cat /sys/block/$ddb_disk_name/device/state)" ]; do sleep 5; done
echo "Wait for /dev/$data_disk_name running state"
while [ "running" != "$(cat /sys/block/$data_disk_name/device/state)" ]; do sleep 5; done
date

data_size=$(($data_disk_size-$install_plus_log_disk_size))G

ddb_size=$((ddb_disk_size * 90/100))G # allocate 90% and keep 10% for COW space

pvcreate /dev/$ddb_disk_name
pvcreate /dev/$data_disk_name
vgcreate  vg_metallic /dev/$data_disk_name
vgcreate  vg_metallic_2 /dev/$ddb_disk_name
lvcreate -n lv_install -L ${install_size}G vg_metallic
lvcreate -n lv_log -L ${log_size}G vg_metallic
lvcreate -n lv_data -L $data_size vg_metallic
lvcreate -n lv_ddb -L $ddb_size vg_metallic_2
mkdir /opt/metallic
mkdir /var/log/metallic
mkdir /var/opt/metallic_data
mkdir /var/opt/metallic_ddb
mkfs -t xfs /dev/vg_metallic/lv_install
mkfs -t xfs /dev/vg_metallic/lv_log
mkfs -t xfs /dev/vg_metallic/lv_data
mkfs -t xfs /dev/vg_metallic_2/lv_ddb
mount /dev/vg_metallic/lv_install /opt/metallic
mount /dev/vg_metallic/lv_log /var/log/metallic
mount /dev/vg_metallic/lv_data /var/opt/metallic_data
mount /dev/vg_metallic_2/lv_ddb /var/opt/metallic_ddb
echo "/dev/vg_metallic/lv_install /opt/metallic xfs defaults,nofail 0 0" | tee -a /etc/fstab
echo "/dev/vg_metallic/lv_log /var/log/metallic xfs defaults,nofail 0 0" | tee -a /etc/fstab
echo "/dev/vg_metallic/lv_data /var/opt/metallic_data xfs defaults,nofail 0 0" | tee -a /etc/fstab
echo "/dev/vg_metallic_2/lv_ddb /var/opt/metallic_ddb xfs defaults,nofail 0 0" | tee -a /etc/fstab

mkdir /var/opt/metallic_data/metallicPkg
cd /var/opt/metallic_data/metallicPkg
yum -y install wget
wget ${backupGatewayPackage} -q
tar -xf LinuxCloudBackupGateway64.tar

localHostname=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/name?api-version=2017-08-01&format=text")
instanceid=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2017-08-01&format=text")
clientname=$localHostname-$instanceid
/var/opt/metallic_data/metallicPkg/LinuxCloudBackupGateway64/pkg/silent_install -clientname $clientname -clienthost $localHostname -authcode ${companyAuthCode}

rm -rf /var/opt/metallic_data/metallicPkg

# chmod 0777 AzueLinuxDeploy.sh && sudo dos2unix AzueLinuxDeploy.sh && sudo ./AzueLinuxDeploy.sh "https://sredownloadcenter.blob.core.windows.net/m050/LinuxCloudBackupGateway64.tar" "3113FC08F">> logfile.txt 2>&1
