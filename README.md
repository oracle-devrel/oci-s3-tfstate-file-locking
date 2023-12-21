# oci-s3-tfstate-file-locking
ScyllaDB deployment to support Terraform state file locking when using S3 as a backend

[![License: UPL](https://img.shields.io/badge/license-UPL-green)](https://img.shields.io/badge/license-UPL-green) [![Quality gate](https://sonarcloud.io/api/project_badges/quality_gate?project=oracle-devrel_oci-s3-tfstate-file-locking)](https://sonarcloud.io/dashboard?id=oracle-devrel_oci-s3-tfstate-file-locking)

## Introduction

In the dynamic world of cloud computing, Infrastructure as Code (IaC) has emerged as a crucial approach for organizations seeking to effectively manage their infrastructure. IaC's key advantage lies in its ability to promote consistency, automation, version control, and collaboration, making it an indispensable element of cloud-native IT strategies.

Terraform stands out as a prominent IaC tool; it stores a depiction of your infrastructure objects and their dependencies in a configuration file named `terraform.tfstate`.

In a collaborative environment where multiple team members manage the cloud infrastructure, storing the `terraform.tfstate` locally becomes challenging. To address this, Terraform offers a feature called "remote backends" to enable the storage of the state file in a shared location. Some of the backends support tfstate locking while `plan` or `apply` operations run to ensure data integrity and prevent conflicts.

This tutorial will focus on how to setup the [S3 Compatible backend](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/terraformUsingObjectStore.htm#s3) and [ScyllaDB's DynamoDB-compatible API](https://www.scylladb.com/alternator/) to enable state file locking.

 
## Prerequisites

* [Sign up](https://www.oracle.com/cloud/free/) or [Sign in](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/signingin.htm) to your Oracle Cloud account.

## Deploy

### Automated deployment

Click below button, fill-in required values and `Apply`.

[![Deploy to OCI](https://docs.oracle.com/en-us/iaas/Content/Resources/Images/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/oracle-devrel/oci-s3-tfstate-file-locking/archive/refs/tags/v1.0.zip)


### Manual deployment

 **Prerequisites:** `terraform`, `oci` - already configured

1. Create a file named `terraform.auto.tfvars` in the root directory using below list of variables and update associated values based on your use-case:

    ```
    compartment_id = "ocid1.compartment.oc1.....abcd1"
    tenancy_ocid    = "ocid1.tenancy.oc1.....abcd1"
    ssh_public_keys = "<ssh-public-key>"
    create_vcn = true
    AWS_ACCESS_KEY = "<access_key>" # https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm#Working2
    AWS_SECRET_KEY = "<secret_key>" # https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm#Working2
    region = "<region>" # e.g.: eu-frankfurt-1
    ```

2. Execute `terraform init`
3. Execute `terraform plan`
4. Execute `terraform apply`

## Test

1. Navigate to the [OCI CloudShell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellgettingstarted.htm#Getting_Started_with_Cloud_Shell).
2. Create a new directory named: `tf-locking-test`
3. Inside the new directory create a file `main.tf` with the sample script from the stack deployment output.
4. Execute `terraform init`, `terraform apply`
5. Confirm that the tfstate file was stored in the OCI Bucket.

## Notes/Issues
* Object Storage Bucket can't be destroyed if it's not empty. Before executing `terraform destroy` ensure that the bucket has no file.
* On the ScyllaDB instance, there is a Python script (`/home/opc/script.py`) that would allow you to list the current tables, create new tables, remove existing tables and remove entries from the existing tables.

## URLs
* [Launching an Instance](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/launchinginstance.htm)
* [API Gateway documentation](https://docs.oracle.com/en-us/iaas/Content/APIGateway/Concepts/apigatewayoverview.htm)
* [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
* [Sign in to your Oracle Cloud Account](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/signingin.htm)
* [ScyllaDB homepage](https://www.scylladb.com/)
* [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)


## Contributing
This project is open source. Please submit your contributions by forking this repository and submitting a pull request! Oracle appreciates any contributions that are made by the open-source community.

## License
Copyright (c) 2023 Oracle and/or its affiliates.

Licensed under the Universal Permissive License (UPL), Version 1.0.

See [LICENSE](LICENSE) for more details.

ORACLE AND ITS AFFILIATES DO NOT PROVIDE ANY WARRANTY WHATSOEVER, EXPRESS OR IMPLIED, FOR ANY SOFTWARE, MATERIAL OR CONTENT OF ANY KIND CONTAINED OR PRODUCED WITHIN THIS REPOSITORY, AND IN PARTICULAR SPECIFICALLY DISCLAIM ANY AND ALL IMPLIED WARRANTIES OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE.  FURTHERMORE, ORACLE AND ITS AFFILIATES DO NOT REPRESENT THAT ANY CUSTOMARY SECURITY REVIEW HAS BEEN PERFORMED WITH RESPECT TO ANY SOFTWARE, MATERIAL OR CONTENT CONTAINED OR PRODUCED WITHIN THIS REPOSITORY. IN ADDITION, AND WITHOUT LIMITING THE FOREGOING, THIRD PARTIES MAY HAVE POSTED SOFTWARE, MATERIAL OR CONTENT TO THIS REPOSITORY WITHOUT ANY REVIEW. USE AT YOUR OWN RISK. 
