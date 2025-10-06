#cloud-config

# uncomment if you want to upgrade packages on first boot, but this takes time
# package_upgrade: true

hostname: ${hostname}

packages:
  - openssh-server
  - bash-completion
  - vim
  - ansible
  - git

users:
  - name: ${username}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - "${public_key}"

runcmd:
  - systemctl enable ssh
  - systemctl start ssh
  - cd /opt/ansible && ansible-galaxy install -r requirements.yml
  #- git clone https://github.com/yourorg/infra-ansible.git /opt/ansible
  #- ansible-playbook site.yml -i localhost