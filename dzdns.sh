#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to display a colorful banner
print_banner() {
    echo -e "${CYAN}#############################################"
    echo -e "${GREEN}   Link Extractor and DNS Checker Script"
    echo -e "${CYAN}#############################################"
    echo -e "${WHITE}                Version 1.0"
    echo -e "${CYAN}#############################################"
}

# Function to display a spinning bar during long operations
spin() {
    local pid="$1"
    local delay=0.1
    local spinchars='/-\|'
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${spinchars:i++%${#spinchars}:1}"
        sleep "$delay"
    done
    printf "\r"  # Clear the spinning character
}

# Function to select a random user agent from the array
random_user_agent() {
    local user_agents=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15"
        "Mozilla/5.0 (Linux; Android 10; Pixel 3 XL) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
        "Mozilla/5.0 (Linux; Ubuntu; X11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36"
    )
    echo "${user_agents[RANDOM % ${#user_agents[@]}]}"
}

# Function to extract all links from a given URL and retrieve DNS information
extract_links_and_dns_cli() {
    local input_url="$1"

    # Step 1: Extract links from the input URL
    echo "Extracting links from $input_url..."
    #local links=$(curl -s "$input_url" | grep -oP 'href="\K(https?://[^"]+|/[^"]+)' | sed "s|^|$input_url|" | sort -u)
    local links=$(curl -s "$input_url" | grep -oP 'href="\K(https?://[^"]+|/[^"]+)' | sort -u)

    # Step 2: Loop through each link to get DNS information from HTTP response
    for link in $links; do
        # Check if the link is a relative URL
        if [[ $link != http* ]]; then
            # If it's a relative URL, form the complete URL
            link="${input_url%/*}/$link"
        fi
        # Print the link being processed
        echo "Checking link: $link"

        # Get the hostname from the link
        host=$(echo "$link" | awk -F/ '{print $3}')

        # Get DNS info using dig
        dns_info=$(dig +short "$host")

        # Get HTTP response information using curl
        curl_output=$(curl -s -o /dev/null -w "%{http_code} %{url_effective}\t\t\n" "$link")

        # Extract and print the DNS info
        if [[ -n "$dns_info" ]]; then
            echo "DNS for $host: $dns_info"
        else
            echo "No DNS info for $host"
        fi

        # Print the HTTP response
        echo "Response: $curl_output"
    done
}



# Function to extract all links from a given URL and retrieve DNS information
extract_links_and_dns() {
    local input_url="$1"

    # Validate URL
    if [[ ! "$input_url" =~ ^https?:// ]]; then
        echo -e "${RED}Invalid URL. Please provide a valid HTTP or HTTPS URL.${NC}"
        exit 1
    fi

    # Prepare to show progress bar
    ( 
        echo "30" "Extracting links from $input_url..."
        sleep 1
        
        # Start link extraction
        links=$(curl -s -A "$(random_user_agent)" "$input_url" | grep -oP 'href="\K(https?://[^"]+|/[^"]+)' | sort -u)
        
        echo "50" "Retrieved links, now processing..."
        sleep 1
        
        # Loop through links to get DNS and HTTP response
        total_links=$(echo "$links" | wc -l)
        count=0
        
	clear

        # Format output as a table
        echo -e "\nExtracted Links:\n"
        printf "%-50s %-20s %-30s\n" "Link" "DNS Info" "HTTP Response"
        printf "%-50s %-20s %-30s\n" "----" "--------" "--------------"

        while IFS= read -r link; do
            # Check if the link is a relative URL
            if [[ $link != http* ]]; then
                link="${input_url%/*}/$link"
		echo -e "\nExtracted Links:\n"
        	printf "%-50s %-20s %-30s\n" "Link" "DNS Info" "HTTP Response"
        	printf "%-50s %-20s %-30s\n" "----" "--------" "--------------"

            fi
            
            # Get the hostname from the link
            host=$(echo "$link" | awk -F/ '{print $3}')
            
            # Get DNS info using dig
            dns_info=$(dig +short "$host")
            
            # Get HTTP response information using curl
            curl_output=$(curl -s -A "$(random_user_agent)" -o /dev/null -w "%{http_code} %{url_effective}" "$link")
            
            # Print the link, DNS info, and HTTP response in table format
            printf "%-50s %-20s %-30s\n" "$link" "$dns_info" "$curl_output"
            
            # Increment progress
            count=$((count + 1))
            echo $((50 + (count * 50 / total_links))) "Processing link $count of $total_links..."
        done <<< "$links"
        
        echo "100" "Finished processing links."
    ) 

}

# Main script execution
print_banner

sleep 3

# Ask for user confirmation to start
if ( dialog --yesno "Do you want to start the link extraction and DNS checking process?" 7 60 ); then
    if [[ $# -eq 0 ]]; then
        echo -e "${YELLOW}Usage: $0 <URL>${NC}"
        exit 1
    fi

    clear
    # Call the function with the provided URL argument
    extract_links_and_dns "$1"

    extract_links_and_dns_cli "$1"
else
    echo "Operation canceled by the user."
    exit 0
fi
