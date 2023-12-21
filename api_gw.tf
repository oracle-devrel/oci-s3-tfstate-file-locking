## Copyright (c) 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_apigateway_gateway" "apigw" {
  compartment_id = local.compartment_id
  endpoint_type  = "PUBLIC"
  subnet_id      = var.create_vcn ? module.vcn[0].subnet_id["public-sn"] : var.existing_pub_subnet

  defined_tags               = var.defined_tags
  display_name               = var.append_suffix ? "${var.apigw_display_name}-${random_string.state_id.id}" : var.apigw_display_name
  freeform_tags              = var.freeform_tags
  network_security_group_ids = [oci_core_network_security_group.scyllaDB_NSG.id]

  response_cache_details {

    type = "NONE"
  }

  lifecycle {
    ignore_changes = [defined_tags["Oracle-Tags.CreatedBy"], defined_tags["Oracle-Tags.CreatedOn"]]
  }
}


resource "oci_apigateway_deployment" "apigw_deployment" {
  compartment_id = local.compartment_id
  gateway_id     = oci_apigateway_gateway.apigw.id
  path_prefix    = "/"
  specification {
    request_policies {
      mutual_tls {
        allowed_sans                     = []
        is_verified_certificate_required = false
      }
    }
    routes {
      backend {
        type                       = "HTTP_BACKEND"
        connect_timeout_in_seconds = 60
        is_ssl_verify_disabled     = true
        send_timeout_in_seconds    = 10
        url                        = "http://${oci_core_instance.scyllaDB.private_ip}:8000/$${request.path[requested_path]}"
      }
      path = "/{requested_path*}"

      methods = ["ANY"]
      request_policies {
        header_transformations {

          set_headers {
            items {
              name   = "Host"
              values = [oci_apigateway_gateway.apigw.hostname]

              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }
  }

  defined_tags  = var.defined_tags
  display_name  = var.append_suffix ? "${var.apigw_display_name}-deployment-${random_string.state_id.id}" : "${var.apigw_display_name}-deployment"
  freeform_tags = var.freeform_tags

  lifecycle {
    ignore_changes = [defined_tags["Oracle-Tags.CreatedBy"], defined_tags["Oracle-Tags.CreatedOn"]]
  }
}
