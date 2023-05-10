#!/bin/bash
# AWS Route53 export

usage() {
  local cmd=$(basename "$0")
  echo -e >&2 "\nUsage: $cmd {--id ZONE_ID --domain ZONE_NAME}\n"
  exit 1
}

while [[ $1 ]]; do
  if   [[ $1 == --id ]];     then shift; zone_id="$1"
  elif [[ $1 == --domain ]]; then shift; zone_name="$1"
  else usage
  fi
  shift
done

if [[ $zone_name ]]; then
  zone_id=$(
    aws route53 list-hosted-zones --output json \
      | jq -r ".HostedZones[] | select(.Name == \"$zone_name.\") | .Id" \
      | head -n1 \
      | cut -d/ -f3
  )
  echo >&2 "+ Found zone id: '$zone_id'"
fi
[[ $zone_id ]] || usage

aws route53 list-resource-record-sets --hosted-zone-id $zone_id --output json \
| jq -jr '.ResourceRecordSets[] | "\(.Name)\t\(.TTL // "ALIAS")\t\(.Type)\t\(.ResourceRecords[]?.Value // "")\t\(.AliasTarget?.HostedZoneId // "")\t\(.AliasTarget?.DNSName // "")\t\(.AliasTarget?.EvaluateTargetHealth // "")\n"'