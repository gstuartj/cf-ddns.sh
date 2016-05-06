#!/bin/sh
# cf-ddns.sh - https://github.com/gstuartj/cf-ddns.sh/
# A minimal, portable DDNS client for CloudFlare API v4 meant for use w/ cron
# Requires: curl (w/ HTTPS support), grep, awk

helptext=`cat << ENDHELP
Usage: cf-ddns.sh [OPTION] -e=EMAIL -a=APIKEY -z=ZONENAME -r=RECORDNAME
  Or:  cf-ddns.sh [OPTION] -e=EMAIL -a=APIKEY -y=ZONEID -q=RECORDID
A minimal, portable DDNS client for CloudFlare

Required
  -e=, --email=         CloudFlare account email
  -a=, --apikey=        CloudFlare account API key
  -z=, --zonename=      Zone name in the form of subdomain.domain.tld
    OR
  -y=, --zoneid=        CloudFlare zone ID
  -r=, --recordname=    Record name in the form of subdomain.domain.tld
    OR
  -q=, --recordid=      CloudFlare record ID

Options
  -f, --force           Force a DNS update, even if WAN IP hasn't changed
  -w=, --wan=           Manually specify WAN IP address, skip detection
  --get-zone-id         Print zone ID corresponding to zone name and exit
  --get-record-id       Print record ID corresponding to record name and exit
  -h, --help            Print this message and exit
ENDHELP`


#Configuration - these options can be hard-coded or passed as parameters
###############
# CF credentials - required
cf_email=''
cf_api_key=''
# Zone name - can be blank if zone_id is set
zone_name=''
# Zone ID - if blank, will be looked up using zone_name
zone_id='' # If blank, will be looked up
# DNS record name  (e.g. domain.tld or subdomain.domain.tld)
# - can be blank if record_id is set
record_name=''
# DNS record ID - if blank, will be looked up using record_name
record_id=''

###############
#The defaults below should be fine.
# Command to run for curl requests. If using alternate version, specify path.
curl_command='curl'
# WAN address - DNS A record will be updated to point to this address
WAN_addr=''
# Internal hostnames for WAN address lookup
# - (optional, will fallback to external source)
internal_wan_hostnames='wan wan-ip wan1-ip'
# External WAN service. Do not include protocol. HTTPS will be tried first.
# URL should return ONLY the IP address as a response
external_WAN_query='https://ifconfig.io/ip'
# Where to store the address from our last update. /tmp/ is fine.
storage_dir='/tmp/'
# Force update if address hasn't changed?
force=false
# CloudFlare Zones API (v4) URL
cf_api_url='https://api.cloudflare.com/client/v4/'
#END CONFIGURATION



#Functions
###############
validate_ip_addr () {
	if [ -z $1 ]; then return 1; fi
	if [ $1 != "${1#*[0-9].[0-9]}" ] && [ "${1}" != "${1#*:[0-9a-fA-F]}" ]; then
                return 1
        fi
	return 0
}


get_WAN_addr () {
	# Go through internal WAN hostnames and get WAN IP, if possible
	for i in $internal_wan_hostnames; do
		local WAN_lookup
        	WAN_lookup=`nslookup ${i} | awk '/^Address: / { print $2 }'`
        	if [ -n $WAN_lookup ]; then
                	continue
        	fi
	done

	# If internal WAN hostnames didn't return an IP, fallback to external service
	if [ -z $WAN_lookup ]; then
        	WAN_lookup=`${curl_command} -s ${external_WAN_query}`
	fi

	if [ ! $WAN_lookup ]; then
        	echo "Couldn't determine WAN IP. Please specify as an argument."
		WAN_lookup=''
        	exit 1
	fi

        if validate_ip_addr $WAN_lookup; then
        	WAN_addr="${WAN_lookup}"
		return 0
	fi

	return 1
}


get_zone_id () {
	if [ -z $zone_name ]; then
		echo "No zone name provided."
		exit 1
	fi

	local zones
	zones=`${curl_command} -s -X GET "${cf_api_url}/zones?name=${zone_name}" -H "X-Auth-Email: ${cf_email}" -H "X-Auth-Key: ${cf_api_key}" -H "Content-Type: application/json"`

        if [ ! "${zones}" ]; then
                echo "Request to API failed during zone lookup."
                exit 1
        fi

	if [ -n "${zones##*\"success\":true*}" ]; then
		echo "Failed to lookup zone ID. Check zone name or specify an ID."
		echo "${zones}"
                exit 1
	fi

	zone_id=`echo "${zones}" | grep -Po '(?<="id":")[^"]*' | head -1`
	return 0
}


get_record_id () {
	if [ -z $record_name ]; then
                echo "No record name provided."
                exit 1
        fi

        if [ -z $zone_name ] && [ -z $zone_id ]; then
                echo "No zone name or ID provided."
                exit 1
        fi

	# No zone ID? Look it up by name.
	if [ -z $zone_id ] && [ -n $zone_name ]; then
		get_zone_id
	fi

	local records
	records=`${curl_command} -s -X GET "${cf_api_url}/zones/${zone_id}/dns_records?name=${record_name}&type=A" -H "X-Auth-Email: ${cf_email}" -H "X-Auth-Key: ${cf_api_key}" -H "Content-Type: application/json"`

        if [ ! "${records}" ]; then
                echo "Request to API failed during record lookup."
                exit 1
        fi

        if [ -n "${records##*\"success\":true*}" ]; then
                echo "Failed to lookup DNS record ID. Check record name or specify an ID."
                echo "${records}"
                exit 1
        fi

	records=`echo "${records}" | grep -Po '(?<="id":")[^"]*'`
	local records_count
	records_count=`echo "${records}" | wc -w`

        if [ $records_count -gt 1 ]; then
                echo "Multiple DNS A records match ${record_name}. Please specify a record ID."
                exit 1
        fi

	record_id="${records}"
	return 0
}
#End functions


#Main
###############
# Remove any trailing slashes from storage_dir and cf_api_url
storage_dir=${storage_dir%%+(/)}
cf_api_url=${cf_api_url%%+(/)}

# Get options and arguments from the command line
for key in "$@"; do
	case $key in
	-z=*|--zonename=*)
		zone_name="${key#*=}"
	shift
	;;
	-r=*|--recordname=*)
		record_name="${key#*=}"
	shift
	;;
	-y=*|--zoneid=*)
		zone_id="${key#*=}"
	shift
	;;
	-q=*|--recordid=*)
		record_id="${key#*=}"
	shift
	;;
	-e=*|--email=*)
		cf_email="${key#*=}"
	shift
	;;
	-a=*|--apikey=*)
		cf_api_key="${key#*=}"
	shift
	;;
        -w=*|--wan=*)
                WAN_addr="${key#*=}"
		if ! validate_ip_addr "${WAN_addr}"; then
                	echo "${WAN_addr} is not a valid WAN IP."
			WAN_addr=''
                	exit 1
		fi
        shift
        ;;
        -f|--force)
                force=true
        shift
        ;;
	--get-zone-id)
                get_zone_id
		echo "Zone ID for ${zone_name}:"
		echo "${zone_id}"
		exit 0
        shift
        ;;
        --get-record-id)
                get_record_id
                echo "Record ID for ${zone_name}:"
                echo "${record_id}"
                exit 0
        shift
	;;
	-h|--help)
		echo "${helptext}"
		exit 0
	;;
	*)
		echo "Unknown option '${key}'"
		exit 1
	;;
	esac
done

# Check if curl supports https
curl_https_check=`curl --version`
if [ -n "${curl_https_check##*https*}" ]; then
	echo "Your version of curl doesn't support HTTPS. Exiting."
	exit 1
fi

# If we need to look up a zone/record ID from the names, do so
if [ -z $zone_id ]; then
	get_zone_id
fi
if [ -z $record_id ]; then
        get_record_id
fi

# If address from previous update was saved, load it
prev_addr=''
prev_addr_file="${storage_dir}/cf-ddns_${zone_id}_${record_id}.addr"
if [ -f $prev_addr_file ]; then
        prev_addr=`cat ${prev_addr_file}`
fi

if [ -z $WAN_addr ]; then get_WAN_addr; fi

if ! validate_ip_addr $WAN_addr; then
	echo "${WAN_addr} is not a valid WAN IP."
        exit 1
fi

# No change. Stop unless force is specified.
if [ -n $prev_addr ] && [ $prev_addr = $WAN_addr ] && [ $force = false ]; then
       	echo 'WAN IP appears unchanged. You can force an update with -f.'
       	exit 0

fi

echo "WAN IP: $WAN_addr"

# Perform record update
api_dns_update=`${curl_command} -s -X PUT "${cf_api_url}/zones/${zone_id}/dns_records/${record_id}" -H "X-Auth-Email: ${cf_email}" -H "X-Auth-Key: ${cf_api_key}" -H "Content-Type: application/json" --data "{\"id\":\"${zone_id}\",\"type\":\"A\",\"name\":\"${record_name}\",\"content\":\"${WAN_addr}\"}"`

if [ ! "${api_dns_update}" ]; then
	echo "There was a problem communicating with the API server. Check your connectivity and parameters."
	echo "${api_dns_update}"
	exit 1
fi

if [ -n "${api_dns_update##*\"success\":true*}" ]; then
	echo "Record update failed."
	echo "${api_dns_update}"
	exit 1
fi

# Save WAN address to file for comparison on subsequent runs
echo "${WAN_addr}" > $prev_addr_file

echo "Record updated."

exit 0
