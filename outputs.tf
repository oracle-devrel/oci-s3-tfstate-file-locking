## Copyright (c) 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "s3_endpoint" {
  value = "https://${data.oci_objectstorage_namespace.namespace.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}

output "dynamodb_endpoint" {
  value = "https://${oci_apigateway_gateway.apigw.hostname}"
}

output "scyllaDB_private_ip" {
  value = oci_core_instance.scyllaDB.private_ip
}

output "bucket_name" {
  value = var.create_bucket ? oci_objectstorage_bucket.bucket[0].name : null
}

output "terraform_sample" {
  value = <<-EOT
    resource "null_resource" "hello_world" {
      provisioner "local-exec" {
        command = "echo Hello World"
      }

      provisioner "local-exec" {
        command = "echo 'sleeping for 30 seconds';sleep 30;echo 'done';"
      }

      triggers = {
        run_always = "$${timestamp()}"
      }
    }
    
    terraform {
      backend "s3" {
        bucket = "%{if var.create_bucket}${oci_objectstorage_bucket.bucket[0].name}%{else}<existing-bucket-name>%{endif}" # e.g.: bucket = "sample-bucket"
        region = "${var.region}"  # e.g.: region = "eu-frankfurt-1"
        
        skip_region_validation      = true
        skip_credentials_validation = true
        skip_metadata_api_check     = true
        # skip_requesting_account_id  = true
        # skip_s3_checksum            = true
        
        force_path_style = true
        # use_path_style = true
        # insecure       = true
        
        # For best practice on how to set credentials access: https://developer.hashicorp.com/terraform/language/settings/backends/s3#access_key
        
        access_key = "${var.AWS_ACCESS_KEY}"
        secret_key = "${var.AWS_SECRET_KEY}"
        
        # To determine <objectostrage_namespace> access: https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/understandingnamespaces.htm
        endpoint       = "https://${data.oci_objectstorage_namespace.namespace.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
        # e.g.: endpoint = https://axaxnpcrorw5.compat.objectstorage.eu-frankfurt-1.oraclecloud.com

        # ScyllaDB TLS endpoint, configured using the API Gateway:
        dynamodb_endpoint = "https://${oci_apigateway_gateway.apigw.hostname}"
        # e.g.: dynamodb_endpoint = "https://fj4etyuvz3s57jdsadsadsadsa.apigateway.eu-frankfurt-1.oci.customer-oci.com"

        # endpoints = {
        #   # To determine <objectostrage_namespace> access: https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/understandingnamespaces.htm
        #   s3       = "https://${data.oci_objectstorage_namespace.namespace.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
        #   # e.g.: s3 = https://axaxnpcrorw5.compat.objectstorage.eu-frankfurt-1.oraclecloud.com
          
        #   # ScyllaDB TLS endpoint, configured using the API Gateway:
        #   dynamodb = "https://${oci_apigateway_gateway.apigw.hostname}"
        #   # e.g.: dynamodb = "https://fj4etyuvz3s57jdsadsadsadsa.apigateway.eu-frankfurt-1.oci.customer-oci.com"
        # }
        
        key            = "demo.tfstate" # the name of the tfstate file
        dynamodb_table = "${var.TF_STATE_TABLE}" # the name of the table in the ScyllaDB
      }
    }
  EOT
}