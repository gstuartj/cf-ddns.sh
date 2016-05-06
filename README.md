# cf-ddns.sh
A minimal, portable DDNS client for automatically updating CloudFlare

Prerequisites
------------
 - curl (with HTTPS support)

Install
------------
Download somewhere on your system and create a cron job to run the script with your parameters on an interval.

Usage
------------
> cf-ddns.sh \[OPTION\] -e=EMAIL -a=APIKEY -z=ZONENAME -r=RECORDNAME

Or:

> cf-ddns.sh \[OPTION\] -e=EMAIL -a=APIKEY -y=ZONEID -q=RECORDID

Required parameters
------------
 -e=, --email=         CloudFlare account email
 -a=, --apikey=        CloudFlare account API key
 -z=, --zonename=      Zone name in the form of subdomain.domain.tld
   OR
 -y=, --zoneid=        CloudFlare zone ID
 -r=, --recordname=    Record name in the form of subdomain.domain.tld
   OR
 -q=, --recordid=      CloudFlare record ID

OPTIONS
 -f, --force           Force a DNS update, even if WAN IP hasn't changed
 -w=, --wan=           Manually specify WAN IP address, skip detection
 --get-zone-id         Print zone ID corresponding to zone name and exit
 --get-record-id       Print record ID corresponding to record name and exit
 -h, --help            Print this message and exit
