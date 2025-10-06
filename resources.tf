# create a new SSH key
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}
resource "local_file" "ssh_key_private" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "./terraform.tfstate.d/default/id_rsa"

  provisioner "local-exec" {
    command = "chmod 400 ./terraform.tfstate.d/default/id_rsa"
  }
}
resource "local_file" "ssh_key_public" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "./terraform.tfstate.d/default/id_rsa.pub"
}

# setup a VPC with its ACLs
resource "cloudstack_vpc" "cloudmc_vpc" {
  name         = "cloudmc-terraform-vpc"
  display_text = "VPC created by Terraform"
  cidr         = "10.0.0.0/16"
  vpc_offering = "Default VPC offering"
  project      = var.cloudstack_project
  zone         = var.cloudstack_zone
}

resource "cloudstack_network_acl" "world_to_pub_acl" {
  name    = "world-to-public-acl"
  vpc_id  = cloudstack_vpc.cloudmc_vpc.id
  project = var.cloudstack_project
}
resource "cloudstack_network_acl_rule" "world_to_pub_acl_rule" {
  acl_id = cloudstack_network_acl.world_to_pub_acl.id

  rule {
    action       = "allow"
    cidr_list    = ["0.0.0.0/0"]
    protocol     = "tcp"
    ports        = ["22", "443", "80"]
    traffic_type = "ingress"
  }
}

resource "cloudstack_network_acl" "public_to_data_acl" {
  name    = "public-to-data-acl"
  vpc_id  = cloudstack_vpc.cloudmc_vpc.id
  project = var.cloudstack_project
}
resource "cloudstack_network_acl_rule" "public_to_data_acl_rule" {
  acl_id = cloudstack_network_acl.public_to_data_acl.id

  rule {
    action       = "allow"
    cidr_list    = ["10.0.1.0/24"]
    protocol     = "tcp"
    ports        = ["22","3306"]
    traffic_type = "ingress"
  }
}

# setup two isolated networks in the VPC
resource "cloudstack_network" "acs_public_network" {
  name             = "public-network"
  cidr             = "10.0.1.0/24"
  network_offering = "DefaultIsolatedNetworkOfferingForVpcNetworks"
  acl_id           = cloudstack_network_acl.world_to_pub_acl.id
  vpc_id           = cloudstack_vpc.cloudmc_vpc.id
  project          = var.cloudstack_project
  zone         	   = var.cloudstack_zone
}
resource "cloudstack_network" "acs_data_network" {
  name             = "data-network"
  cidr             = "10.0.2.0/24"
  network_offering = "DefaultIsolatedNetworkOfferingForVpcNetworksNoLB"
  acl_id           = cloudstack_network_acl.public_to_data_acl.id
  vpc_id           = cloudstack_vpc.cloudmc_vpc.id
  project          = var.cloudstack_project
  zone         	   = var.cloudstack_zone
}

# setup instances in each network
resource "cloudstack_instance" "jump_instance" {
  name             = "jump-server"
  service_offering = "S Instance"
  template         = "Ubuntu 24.04 (250123.1354)"
  network_id       = cloudstack_network.acs_public_network.id
  project          = var.cloudstack_project
  zone         	   = var.cloudstack_zone
	user_data        = templatefile("${path.module}/templates/jump_vm_config.tpl", {
    public_key = replace(tls_private_key.ssh_key.public_key_openssh, "\n", "")
    username   = var.vm_username
    hostname   = "jump-server"
  })

  # ensure that `terraform destroy` can clean up networks
  expunge = true
}

resource "cloudstack_instance" "k8s_control_instance" {
  name             = "k8s-control-server-${count.index+1}"
  service_offering = "M Instance"
  template         = "Ubuntu 24.04 (250123.1354)"
  network_id       = cloudstack_network.acs_public_network.id
  project          = var.cloudstack_project
  zone         	   = var.cloudstack_zone
  root_disk_size   = 20
	user_data        = templatefile("${path.module}/templates/k8s_control_config.tpl", {
    public_key = replace(tls_private_key.ssh_key.public_key_openssh, "\n", "")
    username   = var.vm_username
    hostname   = "k8s-control-server-${count.index+1}"
  })
  count            = var.k8s_control_count

  # ensure that `terraform destroy` can clean up networks
  expunge = true
}
resource "cloudstack_instance" "k8s_nodes_instance" {
  name             = "k8s-nodes-server-${count.index+1}"
  service_offering = "Kubernetes-Nodes-Instance"
  template         = "Ubuntu 24.04 (250123.1354)"
  network_id       = cloudstack_network.acs_public_network.id
  project          = var.cloudstack_project
  zone         	   = var.cloudstack_zone
  root_disk_size   = 20
	user_data        = templatefile("${path.module}/templates/k8s_nodes_config.tpl", {
    public_key = replace(tls_private_key.ssh_key.public_key_openssh, "\n", "")
    username   = var.vm_username
    hostname   = "k8s-nodes-server-${count.index+1}"
  })
  count            = var.k8s_nodes_count

  # ensure that `terraform destroy` can clean up networks
  expunge = true
}
resource "cloudstack_instance" "elastic_instance" {
  name             = "elastic-server-${count.index+1}"
  service_offering = "M Instance"
  template         = "Ubuntu 24.04 (250123.1354)"
  network_id       = cloudstack_network.acs_data_network.id
  project          = var.cloudstack_project
  zone         	   = var.cloudstack_zone
  root_disk_size   = 20
	user_data        = templatefile("${path.module}/templates/elastic_config.tpl", {
    public_key = replace(tls_private_key.ssh_key.public_key_openssh, "\n", "")
    username   = var.vm_username
    hostname   = "elastic-server-${count.index+1}"
  })
  count            = var.elastic_count

  # ensure that `terraform destroy` can clean up networks
  expunge = true
}
resource "cloudstack_instance" "mysql_instance" {
  name             = "mysql-server-${count.index+1}"
  service_offering = "MySql-instance"
  template         = "Ubuntu 24.04 (250123.1354)"
  network_id       = cloudstack_network.acs_data_network.id
  project          = var.cloudstack_project
  zone         	   = var.cloudstack_zone
  root_disk_size   = 20
	user_data        = templatefile("${path.module}/templates/mysql_config.tpl", {
    public_key = replace(tls_private_key.ssh_key.public_key_openssh, "\n", "")
    username   = var.vm_username
    hostname   = "mysql-server-${count.index+1}"
  })
  count            = var.mysql_count

  # ensure that `terraform destroy` can clean up networks
  expunge = true
}

# setup mysql+elastic data volume
resource "cloudstack_disk" "mysql_volume" {
  name               = "mysql-volume-data-${count.index+1}"
  attach             = "true"
  disk_offering      = "Custom"
  virtual_machine_id = cloudstack_instance.mysql_instance[count.index].id
  size               = 40
  project            = var.cloudstack_project
  zone               = var.cloudstack_zone
  count              = var.mysql_count
}
resource "cloudstack_disk" "elastic_volume" {
  name               = "elastic-volume-data-${count.index+1}"
  attach             = "true"
  disk_offering      = "Custom"
  virtual_machine_id = cloudstack_instance.elastic_instance[count.index].id
  size               = 40
  project            = var.cloudstack_project
  zone               = var.cloudstack_zone
  count              = var.elastic_count
}


# setup public IPs and port forwards for SSH access
resource "cloudstack_ipaddress" "jump_public_ip" {
  vpc_id     = cloudstack_vpc.cloudmc_vpc.id
  project    = var.cloudstack_project
  zone       = var.cloudstack_zone
}

# setup public IPs and port forwards for SSH access
resource "cloudstack_ipaddress" "k8s_public_ip" {
  vpc_id     = cloudstack_vpc.cloudmc_vpc.id
  project    = var.cloudstack_project
  zone       = var.cloudstack_zone
}


# setup port forwards for SSH access
resource "cloudstack_port_forward" "jump_ssh_pf" {
  ip_address_id = cloudstack_ipaddress.jump_public_ip.id
  project       = var.cloudstack_project

  forward {
    protocol           = "tcp"
    private_port       = 22
    public_port        = 22
    virtual_machine_id = element(cloudstack_instance.jump_instance.*.id, 0)
  }
}

resource "cloudstack_loadbalancer_rule" "k8s_lbr_https" {
  name          = "k8s-https-lbr"
  ip_address_id = cloudstack_ipaddress.k8s_public_ip.id
  project       = var.cloudstack_project
  algorithm     = "leastconn"
  private_port  = 443
  public_port   = 443
  protocol      = "tcp"
  member_ids    = cloudstack_instance.k8s_nodes_instance.*.id
  network_id = cloudstack_network.acs_public_network.id
}

resource "cloudstack_loadbalancer_rule" "k8s_lbr_http" {
  name          = "k8s-http-lbr"
  ip_address_id = cloudstack_ipaddress.k8s_public_ip.id
  project       = var.cloudstack_project
  algorithm     = "leastconn"
  private_port  = 80
  public_port   = 80
  protocol      = "tcp"
  member_ids    = cloudstack_instance.k8s_nodes_instance.*.id
  network_id = cloudstack_network.acs_public_network.id
}


# configure ssh for the jump vm
resource "null_resource" "jump_ssh_setup" {
  # when an instance changes
  triggers = {
    changed = "${cloudstack_instance.jump_instance.*.id[0]}"
  }

  # push the private key to the instance so it can ssh to all other instances
  provisioner "file" {
    content     = tls_private_key.ssh_key.private_key_pem
    destination = "/home/${var.vm_username}/.ssh/id_rsa"
  }

  # lock down the private ssh key so it works
  provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/${var.vm_username}/.ssh/id_rsa"
    ]
  }

  # the ssh connection details for this null resource
  connection {
    type        = "ssh"
    host        = cloudstack_ipaddress.jump_public_ip.ip_address
    user        = var.vm_username
    private_key = tls_private_key.ssh_key.private_key_pem
    port        = "22"
  }
}

locals {
  inventory_ini = <<EOT
[mysql]
vm-1 ansible_host=${cloudstack_instance.mysql_instance[0].ip_address} ansible_user=${var.vm_username}

[elasticsearch]
vm-2 ansible_host=${cloudstack_instance.elastic_instance[0].ip_address} ansible_user=${var.vm_username}

[k8s_controller]
vm-3 ansible_host=${cloudstack_instance.k8s_control_instance[0].ip_address} ansible_user=${var.vm_username}

[k8s_nodes]
vm-4 ansible_host=${cloudstack_instance.k8s_nodes_instance[0].ip_address} ansible_user=${var.vm_username}
vm-5 ansible_host=${cloudstack_instance.k8s_nodes_instance[1].ip_address} ansible_user=${var.vm_username}
EOT
}

resource "local_file" "ansible_inventory" {
  content  = local.inventory_ini
  filename = "./ansible/inventory.ini"
}

resource "null_resource" "copy_inventory" {
  triggers = {
    id = local_file.ansible_inventory.id
  }

  provisioner "local-exec" {
    command = "scp -i ./terraform.tfstate.d/default/id_rsa -r ansible ${var.vm_username}@${cloudstack_ipaddress.jump_public_ip.ip_address}:"
  }
}


output "ansible_copy_command" {
  value = "scp -i ./terraform.tfstate.d/default/id_rsa ansible -r ${var.vm_username}@${cloudstack_ipaddress.jump_public_ip.ip_address}:"
}

output "jump_ssh_command" {
  value = "ssh -i ./terraform.tfstate.d/default/id_rsa ${var.vm_username}@${cloudstack_ipaddress.jump_public_ip.ip_address}"
}


output "ssh_availability" {
  value = "PLEASE NOTE: It may take a few minutes (up to 15-20 min) after deployment for the SSH service to be available on the instances."
}
