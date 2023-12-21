## Copyright (c) 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "random_string" "state_id" {
  length  = 6
  lower   = true
  numeric = false
  special = false
  upper   = false
}

module "vcn" {
  count          = var.create_vcn ? 1 : 0
  source         = "oracle-terraform-modules/vcn/oci"
  version        = "3.6.0"
  compartment_id = coalesce(var.network_compartment_id, local.compartment_id)

  # Standard tags as defined if enabled for use, or freeform
  # User-provided tags are merged last and take precedence
  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags

  create_internet_gateway = true

  create_nat_gateway = true

  create_service_gateway   = true
  lockdown_default_seclist = false
  vcn_cidrs                = [var.vcn_cidr]
  vcn_name                 = var.append_suffix ? "${var.vcn_name}-${random_string.state_id.id}" : var.vcn_name

  subnets = {
    "public-sn" = {
      name       = "public-sn"
      dns_label  = "pub"
      cidr_block = "10.0.0.0/24"
      type       = "public"
    },
    "private-sn" = {
      name       = "private-sn"
      dns_label  = "priv"
      cidr_block = "10.0.1.0/24"
      type       = "private"
    }
  }
}
