#!/bin/bash
if [ ! -d "/data/mysql" ]; then
    sudo mkfs -t ext4 /dev/vdb
    sudo mkdir /data/mysql
    sudo mount /dev/vdb /data/mysql
    #echo "/dev/vdb               /data/mysql                  ext4    defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi
touch /tmp/.mounted_by_mysql_data_script
