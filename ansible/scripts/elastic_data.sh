#!/bin/bash
if [ ! -d "/var/lib/elasticsearch/data" ]; then
    sudo mkfs -t ext4 /dev/vdb
    sudo mkdir -p /var/lib/elasticsearch/data
    sudo mount /dev/vdb /var/lib/elasticsearch/data
    #echo "/dev/vdb               /var/lib/elasticsearch/data                  ext4    defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi
touch /tmp/.mounted_by_elastic_data_script
