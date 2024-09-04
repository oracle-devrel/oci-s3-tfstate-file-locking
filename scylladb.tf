## Copyright (c) 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  # https://canonical-cloud-init.readthedocs-hosted.com/en/latest/reference/merging.html
  default_cloud_init_merge_type = "list(append)+dict(no_replace,recurse_list)+str(append)"
}

# https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config.html
data "cloudinit_config" "scyllaDB" {
  gzip          = true
  base64_encode = true

  # Repository/package installation
  part {
    content_type = "text/cloud-config"
    content = jsonencode({
      # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#package-update-upgrade-install
      package_update  = true
      package_upgrade = false
      packages = compact([
        "yum-utils",
        "docker-ce",
        "docker-ce-cli",
        "containerd.io",
        "docker-buildx-plugin",
        "docker-compose-plugin",
        "python3-pip"
      ])
      yum_repos = {
        "docker-ce" = {
          name     = "Docker CE repo"
          baseurl  = "https://download.docker.com/linux/centos/8/aarch64/stable"
          gpgkey   = "https://download.docker.com/linux/centos/gpg"
          gpgcheck = true
          enabled  = true
        }
      }
    })
    filename   = "10-packages.yml"
    merge_type = local.default_cloud_init_merge_type
  }

  # Start docker services
  part {
    content_type = "text/cloud-config"
    content = jsonencode({
      runcmd = [
        "systemctl start docker.service",
        "systemctl enable docker.service",
        "usermod -aG docker opc"
      ]
    })
    filename   = "20-start-docker.yml"
    merge_type = local.default_cloud_init_merge_type
  }

  # Allow access on port 8000
  part {
    content_type = "text/cloud-config"
    content = jsonencode({
      runcmd = [
        "firewall-offline-cmd --add-port 8000/tcp"
      ]
    })
    filename   = "20-allow-access-port-8000.yml"
    merge_type = local.default_cloud_init_merge_type
  }

  # Create required directories
  part {
    content_type = "text/cloud-config"
    content = jsonencode({
      runcmd = [
        "mkdir -p /home/opc/s3-lock",
        "mkdir -p /home/opc/s3-lock/scylladb",
        "chown -R opc:opc /home/opc"
      ]
    })
    filename   = "30-home.yml"
    merge_type = local.default_cloud_init_merge_type
  }

  # Add .env
  part {
    content_type = "text/cloud-config"
    content = jsonencode({
      # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#write-files
      write_files = [
        {
          content = <<-EOT
              AWS_ACCESS_KEY_ID='${var.AWS_ACCESS_KEY}'
              AWS_SECRET_ACCESS_KEY='${var.AWS_SECRET_KEY}'
              TF_STATE_TABLE='${var.TF_STATE_TABLE}'
            EOT
          path    = "/home/opc/s3-lock/.env"
        },
      ]
    })
    filename   = "30-env.yml"
    merge_type = local.default_cloud_init_merge_type
  }

  # Add ScyllaDB dockerfile
  part {
    content_type = "text/cloud-config"
    content = jsonencode({
      # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#write-files
      write_files = [
        {
          content = <<-EOT
              FROM scylladb/scylla:5.2.8
              RUN echo "alternator_enforce_authorization: true" >> /etc/scylla/scylla.yaml
              ENTRYPOINT ["/docker-entrypoint.py"]
            EOT
          path    = "/home/opc/s3-lock/scylladb/scylladb.Dockerfile"
        },
      ]
    })
    filename   = "30-scylladb-Dockerfile.yml"
    merge_type = local.default_cloud_init_merge_type
  }

  # Add docker-compose
  part {
    content_type = "text/cloud-config"
    content = jsonencode({
      # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#write-files
      write_files = [
        {
          content = <<-EOT
              version: "3.3"

              services:
                scylladb:
                  build:
                    dockerfile: scylladb.Dockerfile
                    context: ./scylladb
                  image: "local-scylla:latest"
                  container_name: "scylladb"
                  restart: always
                  command: ["--alternator-port=8000", "--alternator-write-isolation=always"]
                  ports:
                    - "8000:8000"
                    - "9042:9042"

                scylladb-load-user:
                  image: "scylladb/scylla:5.2.8"
                  container_name: "scylladb-load-user"
                  depends_on:
                    - scylladb
                  entrypoint: /bin/bash -c "sleep 60 && echo loading cassandra keyspace && cqlsh scylladb -u cassandra -p cassandra \
                                            -e \"INSERT INTO system_auth.roles (role,can_login,is_superuser,member_of,salted_hash) \
                                            VALUES ('$${AWS_ACCESS_KEY_ID}',True,False,null,'$${AWS_SECRET_ACCESS_KEY}');\""

                scylladb-create-table:
                  image: "amazon/aws-cli"
                  container_name: "create_table"
                  depends_on:
                    - scylladb
                  env_file: .env
                  entrypoint: /bin/sh -c "sleep 70 && aws dynamodb create-table --table-name $${TF_STATE_TABLE} \
                                          --attribute-definitions AttributeName=LockID,AttributeType=S \
                                          --key-schema AttributeName=LockID,KeyType=HASH --billing-mode=PAY_PER_REQUEST \
                                          --region 'None' --endpoint-url=http://scylladb:8000"
            EOT
          path    = "/home/opc/s3-lock/docker-compose.yaml"
        },
      ]
    })
    filename   = "30-scylladb-docker-compose.yml"
    merge_type = local.default_cloud_init_merge_type
  }

  # Start ScyllaDB service
  part {
    content_type = "text/cloud-config"
    content = jsonencode({
      runcmd = [
        "cd /home/opc/s3-lock/",
        "docker compose up -d"
      ]
    })
    filename   = "40-start-service.yml"
    merge_type = local.default_cloud_init_merge_type
  }

  # Add ScyllaDB helper script
  part {
    content_type = "text/cloud-config"
    content = jsonencode({
      # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#write-files
      write_files = [
        {
          content = <<-EOT
              import sys
              
              import boto3
              from botocore.exceptions import ClientError 

              endpoint_url = 'http://localhost:8000'
              region_name="None"
              aws_access_key_id = '${var.AWS_ACCESS_KEY}'
              aws_secret_access_key = '${var.AWS_SECRET_KEY}'
              initial_table = '${var.TF_STATE_TABLE}'
              
              def list_tables():
                  client = boto3.client('dynamodb', endpoint_url=endpoint_url, region_name=region_name,
                              aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key)
                  response = client.list_tables()
                  
                  return [ table_name for table_name in response['TableNames'] ]

              def check_table_status(table_name):
                  client = boto3.client('dynamodb', endpoint_url=endpoint_url, region_name=region_name,
                                  aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key)

                  response = client.describe_table(TableName=table_name)

                  return f'{response["Table"]["TableName"]} {response["Table"]["TableStatus"]}'

              def create_table(table_name):
                  client = boto3.client('dynamodb', endpoint_url=endpoint_url, region_name=region_name,
                                  aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key)

                  response = client.create_table(TableName=table_name, 
                                                AttributeDefinitions=[{'AttributeName': 'LockID', 'AttributeType': 'S'}],
                                                KeySchema=[{'AttributeName': 'LockID', 'KeyType': 'HASH' }],
                                                BillingMode='PAY_PER_REQUEST')

                  return response["TableDescription"]["TableStatus"]

              def edit_table_items(table_name):
                  client = boto3.client('dynamodb', endpoint_url=endpoint_url, region_name=region_name,
                                  aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key)    
                  
                  scan_response = client.scan(
                          TableName=table_name,
                      )

                  print(scan_response['Items'])

                  entry_to_delete = input("What is the LockID value you would like to delete? ")

                  delete_response = client.delete_item(
                      Key={
                          'LockID': {
                              'S': f'{entry_to_delete}',
                          },
                      },
                      TableName=table_name
                      )
                  
                  return delete_response

              def delete_table(table_name):
                  client = boto3.client('dynamodb', endpoint_url=endpoint_url, region_name=region_name,
                                  aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key)

                  response = client.delete_table(TableName=table_name)

                  return response["TableDescription"]["TableStatus"]

              def menu():
                  print('1) List all the tables')
                  print('2) Check the table status')
                  print('3) Create a new table')
                  print('4) Edit the table')
                  print('5) Delete the table')
                  print('q) Quit')

              if __name__ == '__main__':
                  print('Initially deployed table:', initial_table)
                  
                  while True:
                      menu()

                      option = input("What operation would you like to perform? ")
                      try:
                          if option.strip() == '1':
                              print(list_tables())

                          if option.strip() == '2':
                              table_name = input("What is the name of the table? ")
                              print(check_table_status(table_name.strip()))        
                          
                          if option.strip() == '3':
                              table_name = input("What is the new table name? ")
                              print(create_table(table_name.strip()))
                          
                          if option.strip() == '4':
                              table_name = input("What is the name of the table you would like to edit? ")
                              print(edit_table_items(table_name.strip()))

                          
                          if option.strip() == '5':
                              table_name = input("What is the name of the table you would like to delete? ")
                              print(delete_table(table_name.strip()))
                      
                          if option.strip().lower() == 'q':
                              sys.exit(0)
                              
                      except ClientError as e:
                          print(f'Unexpected client error occured: {e}')


                      print()

            EOT
          path    = "/home/opc/script.py"
        },
      ]
    })
    filename   = "50-helper-script.yml"
    merge_type = local.default_cloud_init_merge_type
  }
}



resource "oci_core_instance" "scyllaDB" {
  #Required
  availability_domain = coalesce([for entry in data.oci_identity_availability_domains.ad.availability_domains : entry.name]...)
  compartment_id      = local.compartment_id
  shape               = "VM.Standard.A1.Flex"

  #Optional
  agent_config {

    #Optional
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false
    plugins_config {
      #Required
      desired_state = "DISABLED"
      name          = "OS Management Service Agent"
    }
    plugins_config {
      #Required
      desired_state = "ENABLED"
      name          = "Bastion"
    }
  }

  create_vnic_details {

    assign_public_ip = false
    defined_tags     = var.defined_tags
    freeform_tags    = var.freeform_tags
    nsg_ids          = [oci_core_network_security_group.scyllaDB_NSG.id]
    subnet_id        = var.create_vcn ? module.vcn[0].subnet_id["private-sn"] : var.existing_priv_subnet
  }


  display_name = var.append_suffix ? "${var.instance_display_name}-${random_string.state_id.id}" : var.instance_display_name

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags

  metadata = {
    ssh_authorized_keys = var.ssh_public_keys
    user_data           = data.cloudinit_config.scyllaDB.rendered
  }


  shape_config {
    memory_in_gbs = 6
    ocpus         = 1
  }

  source_details {
    #Required
    source_id   = local.instance_images[0]
    source_type = "image"
  }

  preserve_boot_volume = false

  lifecycle {
    ignore_changes = [
      metadata, defined_tags["Oracle-Tags.CreatedBy"], defined_tags["Oracle-Tags.CreatedOn"],
      create_vnic_details[0].defined_tags["Oracle-Tags.CreatedBy"], create_vnic_details[0].defined_tags["Oracle-Tags.CreatedOn"]
    ]
  }
}


resource "null_resource" "await_cloudinit" {

  connection {
    bastion_host        = regex("(\\S+)@(\\S+\\.oraclecloud\\.com).+?(\\S+)@([\\d.]+)", oci_bastion_session.session.ssh_metadata["command"])[1]
    bastion_user        = regex("(\\S+)@(\\S+\\.oraclecloud\\.com).+?(\\S+)@([\\d.]+)", oci_bastion_session.session.ssh_metadata["command"])[0]
    bastion_private_key = tls_private_key.bastion_key.private_key_openssh
    host                = regex("(\\S+)@(\\S+\\.oraclecloud\\.com).+?(\\S+)@([\\d.]+)", oci_bastion_session.session.ssh_metadata["command"])[3]
    user                = regex("(\\S+)@(\\S+\\.oraclecloud\\.com).+?(\\S+)@([\\d.]+)", oci_bastion_session.session.ssh_metadata["command"])[2]
    private_key         = tls_private_key.bastion_key.private_key_openssh
    timeout             = "40m"
    type                = "ssh"
  }

  lifecycle {
    replace_triggered_by = [oci_core_instance.scyllaDB]
  }

  provisioner "remote-exec" {
    inline = ["cloud-init status --wait &> /dev/null"]
  }

  provisioner "remote-exec" {
    inline = ["python3 -m pip install --user boto3"]
  }
}
