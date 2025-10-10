SAMPLE CLOUDMC TERRAFORM
================

## Configure a Project in CloudStack

Do the following in the CloudStack Management Server to get setup.

- Create an **Account** with role **DomainAdmin** on the appropriate **Domain**. Set the credentials and other settings as desired.
- Login to the **Domain** you would like to work in, with the **Account**.
  - When logging in, specify the post-ROOT path for the **Domain**.  EG: `/ROOT/parent/child` would be `parent/child`
- Create a **Project** and note its `name` as the `var.cloudstack_project` variable value.
- Navigate to your **Profile** in the top right.
- If you don't already have API Keys, click the 3rd button in from the left, `Generate New API/Secret Keys`
- Copy the `API Key` into `var.cloudstack_api_key`.
- Copy the `Secret Key` into `var.cloudstack_secret_key`.
- Navigate to **Zones** and copy the desired `name` into `var.cloudstack_zone`.
- In the terraform variables, also set; `var.vm_username`

You should now be ready to start running Terraform.

## Running Terraform

```bash
# make sure you have terraform configured correctly
terraform init

# plan and apply.  you can review the plan before typing 'yes'
terraform plan && terraform apply
```

## Updating the VM config

Review the different `templates/*_config.tpl` files to review the packages and configurations installed.

Right now, each of the files are the same, however, they are broken out into different files so the configurations can diverge as applications get installed.

## Troubleshooting

### Can't SSH to a VM

There are two key reasons why this happens.

Usually the error will be: `Network is unreachable`

- The VM has started, but the cloudinit / cloud-config has't finished executing, so SSH isn't ready yet.  This is impacted by the `package_upgrade: true` at the top of the `template/*.tpl` files.
- Terraform is setting up the networking and public IPs too quickly, so the public IP didn't get setup correctly.  You need to **restart the VPC with `Clean Up` enabled**.  This will force the VR to set the configuration sequentially and fix the broken VR config.


## Running Ansible


```bash
# Connect to the jump server
ssh -i ./terraform.tfstate.d/default/id_rsa ${var.vm_username}@${cloudstack_ipaddress.jump_public_ip.ip_address}

# Run ansible to deploy the software on each machine
ansible-playbook site-k3s.yml -i inventory.ini 
```