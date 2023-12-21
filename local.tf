## Copyright (c) 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  compartment_id = coalesce(var.compartment_id, var.compartment_ocid, var.tenancy_ocid)

  instance_images = [for entry in data.oci_core_images.ol8.images : entry.id if can(regex("Oracle-Linux-[\\d.]+-aarch64-[\\d.-]+", entry.display_name))]
}

