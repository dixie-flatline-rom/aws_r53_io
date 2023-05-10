# Route53-to-Terraform Exporter

This utility is a simple Bash script that exports AWS Route 53 DNS records into a Terraform configuration file format. The generated Terraform configuration file can then be used to manage your Route 53 resources using Terraform.

## Prerequisites

1. Bash 4 or later
2. AWS CLI installed and configured with the necessary credentials
3. Terraform installed

## Usage

1. Save the provided script to a file named `route53_to_terraform.sh` and make it executable:

   ```sh
   chmod +x route53_to_terraform.sh
   ```

2. Run the script with the exported Route 53 zone file as an argument:

   ```sh
   ./route53_to_terraform.sh <filename_to_import>
   ```

    Replace <filename_to_import> with the path to the Route 53 zone file you want to convert.

    The script will create a new Terraform configuration file named dns_records_<zone_resource>.tf in the current working directory.

3. Now you can manage your Route 53 resources using Terraform:

   ```sh
   terraform init
   terraform apply
   ```

## Limitations

This script only supports the most common DNS record types (A, AAAA, CNAME, MX, NS, PTR, SOA, SPF, SRV, and TXT), including ALIAS record, a Route53 specific extension to DNS.

It doesn't support importing weighted, latency-based, or failover records.

The script assumes that your AWS CLI is already configured with the necessary credentials to access your Route 53 resources.