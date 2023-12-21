## Copyright (c) 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

data "oci_core_images" "ol8" {
  compartment_id = var.tenancy_ocid

  operating_system         = "Oracle Linux"
  operating_system_version = "8"
}


data "oci_identity_availability_domains" "ad" {
  compartment_id = local.compartment_id
}

data "oci_objectstorage_namespace" "namespace" {
  compartment_id = var.tenancy_ocid
}