#!/bin/bash

EXPORTER_PORT=9100


collect_metrics() {

        IFS=$'\n'

        result_array=($(sudo cat /var/log/auth.log | tail -100 | grep sshd | grep -i failed ))
	
        ip_array=()

	for line in "${result_array[@]}"; do
        	datetime=$(echo "$line" | awk '{print $1" "$2" "$3}')
        	ip=$(echo "$line" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
        	port=$(echo "$line" | grep -oP "(?<=from $ip port )[0-9]+")
        	user=$(echo "$line" | grep -oP "(?<=for ).*(?= from)")
        	if [[ $user == "invalid"* ]]; then
            		user=invalid
        	fi
        	ip_array+=("$datetime $user $ip")
    	done


        #repeat count of each ip, also sorting them
        sorted_ips=$(printf "%s\n" "${ip_array[@]}" | sort -k5,5 | uniq -f 4 -c | sort -k1,1 -n -r)


        echo "# HELP ssh_login_attempts Number of failed SSH login attempts"
        echo "# TYPE ssh_login_attempts gauge"
        while read -r line; do
                count=$(echo "$line" | awk '{print $1}')
                ip=$(echo "$line" | awk '{print $6}')
                #datetime=$(echo "$line" | awk '{$1=""; $2=""; $3=""; print $0}')
		datetime=$(echo "$line" | awk '{print $2" "$3" "$4}')
		#port=$(echo "$line" | awk '{print $3}')
                user=$(echo "$line" | awk '{print $5}')
                echo "ssh_login_attempts{datetime=\"$datetime\", user=\"$user\", ip=\"$ip\", count=\"$count\"}"
        done <<< "$sorted_ips"

}


main() {
    # Start HTTP server to expose metrics
	while true; do
        	(echo -ne "HTTP/1.0 200 OK\r\n"; collect_metrics) | nc -l -p "$EXPORTER_PORT" -q 1 
   		#sleep 10
	done
}

# Run the main function
main




