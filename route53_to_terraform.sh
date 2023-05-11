#!/usr/local/bin/bash
# Generate terraform config from zone_export.sh's output file.

if [ -z "$1" ]; then
  echo "Usage: $(basename $0) <filename_to_import>"
  exit 1
fi

exported_filename=$1

records=()

# load up the records
while read line; do
  IFS=$'\t' read -r -a columns <<< "$line"
  domain=$(echo ${columns[0]} | xargs)

  if [ "${columns[1]}" == "ALIAS" ]; then
    record_type="${columns[1]}"
    alias_record="${columns[4]}"
    zone_id="${columns[3]}"
    eval_health="${columns[5]}"
  else
    ttl=$(echo ${columns[1]} | xargs)
    record_type=$(echo ${columns[2]} | xargs)
    record=$(echo "${columns[3]}" | sed 's/"//g')
  fi

  records+=("$domain,$ttl,$record_type,$record,$alias_record,$zone_id,$eval_health")
done < $exported_filename

# test print
# for key in "${!records[@]}"; do
#   echo "Key: $key, Value: ${records[$key]}"
# done
# exit

# associative arrays
declare -A resource_records
declare -A resource_ttl
declare -A resource_blocks
declare -A resource_alias_zone
declare -A resource_zone_id
declare -A resource_eval_health

# allow for multiple values in a DNS record
for record in "${records[@]}"; do
  IFS=',' read -r -a parts <<< "$record"
  domain="${parts[0]}"
  ttl="${parts[1]}"
  record_type="${parts[2]}"
  record="${parts[3]}"

  # get zone name
  if [ "$record_type" == "SOA" ]; then
    zone_name=$(echo "${parts[0]}" | sed 's/\.$//')
    zone_resource="$(echo "${parts[0]}zone" | sed 's/\./-/g' | sed 's/\*//g' | sed 's/^\-//')"
  fi

  # add it to the resource_records' associative array
  resource_records["$domain $record_type"]="${resource_records["$domain $record_type"]} \"$record\","

  # make it work with extra values (a little ugly)
  resource_ttl["$domain $record_type"]="$ttl"
  resource_alias_zone["$domain $record_type"]="${parts[4]}"
  resource_zone_id["$domain $record_type"]="${parts[5]}"
  resource_eval_health["$domain $record_type"]="${parts[6]}"
done

# build output in TF format
for key in "${!resource_records[@]}"; do
  IFS=' ' read -r -a parts <<< "$key"
  domain="${parts[0]}"
  record_type="${parts[1]}"

  # remove the trailing comma
  record_list="[
    ${resource_records[$key]%,}
    ]"

  resource_name="$(echo "$domain" | sed 's/\./-/g' | sed 's/\*//g' | sed 's/^\-//')"

  if [[ "$record_type" == "ALIAS" ]]; then
    resource_block=$(cat << EOF
resource "aws_route53_record" "${resource_name}-alias-a" {
  zone_id = aws_route53_zone.${zone_resource}.zone_id
  name    = "$domain"
  type    = "A"
  alias {
    name                   = "${resource_alias_zone[$key]}"
    zone_id                = "${resource_zone_id[$key]}"
    evaluate_target_health = "${resource_eval_health[$key]}"
  }
}

EOF
)
  else
    resource_block=$(cat << EOF
resource "aws_route53_record" "${resource_name}-${record_type}" {
  zone_id = aws_route53_zone.${zone_resource}.zone_id
  name    = "$domain"
  type    = "$record_type"
  ttl     = "${resource_ttl[$key]}"
  records = $record_list
}

EOF
)
  fi

  resource_blocks["$resource_name-$record_type"]="$resource_block"
done

# Sort and output the resource blocks
sorted_resource_names=($(echo "${!resource_blocks[@]}" | tr ' ' '\n' | sort -u))

cat > dns_records_${zone_resource}.tf << EOF
terraform {
  backend "local" {
  }
 
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.62.0"
    }
  }
}

resource "aws_route53_zone" "${zone_resource}" {
  name = "$zone_name"
}

EOF

for resource_name in "${sorted_resource_names[@]}"; do
  echo -e "${resource_blocks["$resource_name"]}\n" >> dns_records_${zone_resource}.tf
done

