#!/bin/bash
if [ ! -d "{{ elastic_mount_point }}/data" ]; then
    sudo mkfs -t ext4 {{ elastic_data_disk }}
    sudo mkdir -p {{ elastic_mount_point }}/data
    sudo mount {{ elastic_data_disk }} {{ elastic_mount_point }}/data
    #echo "{{ elastic_data_disk }}               {{ elastic_mount_point }}/data                  ext4    defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi
touch /tmp/.mounted_by_elastic_data_script
