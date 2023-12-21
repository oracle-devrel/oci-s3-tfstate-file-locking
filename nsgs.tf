## Copyright (c) 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_core_network_security_group" "scyllaDB_NSG" {

  compartment_id = coalesce(var.network_compartment_id, local.compartment_id)
  vcn_id         = var.create_vcn ? module.vcn[0].vcn_id : var.vcn_id

  display_name = var.append_suffix ? "${var.instance_display_name}-NSG-${random_string.state_id.id}" : "${var.instance_display_name}-NSG"

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags

  lifecycle {
    ignore_changes = [defined_tags["Oracle-Tags.CreatedBy"], defined_tags["Oracle-Tags.CreatedOn"]]
  }
}

resource "oci_core_network_security_group_security_rule" "ingress" {
  network_security_group_id = oci_core_network_security_group.scyllaDB_NSG.id
  direction                 = "INGRESS"
  protocol                  = "6"

  description = "Allow HTTPS access to the API Gateway endpoint."
  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      max = 443
      min = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "egress" {
  network_security_group_id = oci_core_network_security_group.scyllaDB_NSG.id
  direction                 = "EGRESS"
  protocol                  = "all"

  description      = "Allow all egress."
  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "ingress_ngs_all" {
  network_security_group_id = oci_core_network_security_group.scyllaDB_NSG.id
  direction                 = "INGRESS"
  protocol                  = "all"

  description = "Allow all within NSG."
  source      = oci_core_network_security_group.scyllaDB_NSG.id
  source_type = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "egress_nsg_all" {
  network_security_group_id = oci_core_network_security_group.scyllaDB_NSG.id
  direction                 = "EGRESS"
  protocol                  = "all"

  description      = "Allow all within NSG."
  destination      = oci_core_network_security_group.scyllaDB_NSG.id
  destination_type = "NETWORK_SECURITY_GROUP"
}