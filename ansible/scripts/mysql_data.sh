#!/bin/bash
if [ ! -d "{{ mysql_mount_point }}" ]; then
    sudo mkfs -t ext4 {{ mysql_data_disk }}
    sudo mkdir {{ mysql_mount_point }}
    sudo mount {{ mysql_data_disk }} {{ mysql_mount_point }}
    #echo "{{ mysql_data_disk }}               {{ mysql_mount_point }}                  ext4    defaults,nofail 0 2" | sudo tee -a /etc/fstab
    sudo rm -r {{ mysql_mount_point }}/*
fi
touch /tmp/.mounted_by_mysql_data_script
