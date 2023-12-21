## Copyright (c) 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_objectstorage_bucket" "bucket" {
  count = var.create_bucket ? 1 : 0

  compartment_id = local.compartment_id
  name           = var.append_suffix ? "${var.bucket_name}-${random_string.state_id.id}" : var.bucket_name
  namespace      = data.oci_objectstorage_namespace.namespace.namespace

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags

  lifecycle {
    ignore_changes = [defined_tags["Oracle-Tags.CreatedBy"], defined_tags["Oracle-Tags.CreatedOn"]]
  }
}