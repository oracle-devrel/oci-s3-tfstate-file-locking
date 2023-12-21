## Copyright (c) 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "tls_private_key" "bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


resource "oci_bastion_bastion" "bastion" {

  bastion_type                 = "STANDARD"
  compartment_id               = coalesce(var.network_compartment_id, local.compartment_id)
  target_subnet_id             = var.create_vcn ? module.vcn[0].subnet_id["public-sn"] : var.existing_pub_subnet
  name                         = var.append_suffix ? "${var.instance_display_name}-bastion-${random_string.state_id.id}" : "${var.instance_display_name}-bastion"
  client_cidr_block_allow_list = ["0.0.0.0/0"]

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  lifecycle {
    ignore_changes = [defined_tags["Oracle-Tags.CreatedBy"], defined_tags["Oracle-Tags.CreatedOn"]]
  }
}

resource "null_resource" "wait_for_bastion_plugin" {
  depends_on = [oci_core_instance.scyllaDB]

  provisioner "local-exec" {
    command     = <<-EOT
      timeout 20m bash -c -- 'while true; do [ ! $(oci instance-agent plugin get --instanceagent-id $INSTANCE_ID --compartment-id $COMPARTMENT_ID --plugin-name Bastion --query "data.status || 'NO_RESPONSE'" 2>/dev/null) == "RUNNING" ] && exit 0 ; echo "Waiting for bastion plugin to become active on the instance...";sleep 20; done;'
    EOT
    interpreter = ["/bin/bash", "-c"]

    environment = {
      INSTANCE_ID    = oci_core_instance.scyllaDB.id
      COMPARTMENT_ID = local.compartment_id
    }
  }
}

resource "oci_bastion_session" "session" {
  depends_on = [null_resource.wait_for_bastion_plugin]

  bastion_id = oci_bastion_bastion.bastion.id
  key_type   = "PUB"
  key_details {
    public_key_content = tls_private_key.bastion_key.public_key_openssh
  }

  target_resource_details {
    session_type                               = "MANAGED_SSH"
    target_resource_id                         = oci_core_instance.scyllaDB.id
    target_resource_operating_system_user_name = "opc"
  }

  display_name           = var.append_suffix ? "${var.instance_display_name}-bastion-session-${random_string.state_id.id}" : "${var.instance_display_name}-bastion-session"
  session_ttl_in_seconds = 10800
}