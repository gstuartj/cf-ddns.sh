# cf-ddns.sh
cf-ddns.sh is a minimal, easy to use DDNS client for automatically updating CloudFlare's DNS service to point to your current IP. It was written with portability in mind, so it will run in most POSIX-like shells. (BASH, BusyBox, etc.) It can even work on many embedded systems, like consumer-grade routers.

cf-ddns.sh is based on v4 of the CloudFlare API.

Prerequisites
------------
 - POSIX-ish environment (Linux, OS X, BSD, etc.)
 - curl (requires HTTPS support)

Install
------------
Download to your system and create a cron job to run the script with your parameters on an interval.

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

Options
------------
  -f, --force		Force a DNS update, even if WAN IP hasn't changed  
  -t, --test		Test action without updating DNS record  
  -w=, --wan=		Manually specify WAN IP address, skip detection  
  --get-wan-ip		Determine the WAN IP, print it, and exit  
  --get-zone-id		Print zone ID corresponding to zone name and exit  
  --get-record-id	Print record ID corresponding to record name and exit  
  -h, --help		Print this message and exit  
