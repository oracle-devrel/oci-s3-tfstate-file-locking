## Copyright (c) 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "tenancy_ocid" {}
variable "compartment_ocid" { default = null }
variable "region" { default = null }

# Generic variables
variable "compartment_id" { default = null }

variable "append_suffix" {
  type    = bool
  default = true
}
variable "create_bucket" {
  type    = bool
  default = true
}

variable "bucket_name" { default = "tf-state-bucket" }
variable "AWS_ACCESS_KEY" {}
variable "AWS_SECRET_KEY" {}
variable "TF_STATE_TABLE" { default = "s3-locking-demo" }
variable "defined_tags" {
  type    = map(string)
  default = {}
}
variable "freeform_tags" {
  type    = map(string)
  default = {}
}

# Networking variables
variable "create_vcn" {
  type    = bool
  default = true
}

variable "network_compartment_id" { default = null }

variable "vcn_name" {
  default = "tf-locking-demo"
}

variable "vcn_cidr" {
  default = "10.0.0.0/16"
}

variable "vcn_id" { default = null }
variable "existing_pub_subnet" { default = null }
variable "existing_priv_subnet" { default = null }



# API GW variables
variable "apigw_display_name" { default = "scyllaDB-APIGW" }

# Instance module variables
variable "instance_display_name" { default = "scyllaDB" }
variable "ssh_public_keys" {}

