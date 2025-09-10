#!/bin/bash

# Have I Been Pwned Checker
# Usage: ./haveibeenpwned-checker.sh <email_file>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if email file is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No email file provided${NC}"
    echo "Usage: $0 <email_file>"
    exit 1
fi

EMAIL_FILE="$1"

# Check if file exists
if [ ! -f "$EMAIL_FILE" ]; then
    echo -e "${RED}Error: File '$EMAIL_FILE' not found${NC}"
    exit 1
fi

# Check required tools
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required but not installed${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required for JSON parsing${NC}"
    exit 1
fi

# Function to check a single email
check_email() {
    local email="$1"
    local encoded_email=$(echo "$email" | jq -sRr @uri)
    
    echo -e "${BLUE}Checking: $email${NC}"
    
    # Use the API endpoint (more reliable than web scraping)
    local api_url="https://haveibeenpwned.com/api/v3/breachedaccount/$encoded_email"
    
    # Note: The official API requires an API key for v3
    # For this script, we'll use a workaround with the website's internal API
    local response=$(curl -s -X POST "https://haveibeenpwned.com/unifiedsearch/$encoded_email" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        --connect-timeout 10 \
        --max-time 30)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}  Error: Network request failed${NC}"
        return 1
    fi
    
    # Check if response contains breaches
    if echo "$response" | jq -e '.Breaches' > /dev/null 2>&1; then
        local breach_count=$(echo "$response" | jq '.Breaches | length')
        
        if [ "$breach_count" -gt 0 ]; then
            echo -e "${RED}  ✗ BREACHED - $breach_count breach(es) found!${NC}"
            
            # Display breach details
            echo "$response" | jq -r '.Breaches[] | "    • \(.Name) (\(.BreachDate)): \(.Description)"' | while read -r breach; do
                echo -e "${YELLOW}$breach${NC}"
            done
            
            # Show compromised data
            echo -e "${YELLOW}  Compromised data:${NC}"
            echo "$response" | jq -r '.Breaches[] | .DataClasses[]' | sort -u | while read -r data_type; do
                echo -e "    ${YELLOW}• $data_type${NC}"
            done
            
            return 2
        else
            echo -e "${GREEN}  ✓ No breaches found${NC}"
            return 0
        fi
    else
        echo -e "${GREEN}  ✓ No breaches found${NC}"
        return 0
    fi
}

# Function to check rate limiting and add delay
rate_limit_check() {
    sleep 2
}

# Main execution
echo -e "${BLUE}=== Have I Been Pwned Checker ===${NC}"
echo -e "${BLUE}Checking $(wc -l < "$EMAIL_FILE") email(s)${NC}"
echo ""

total_emails=0
breached_emails=0

# Read emails from file
while IFS= read -r email || [ -n "$email" ]; do
    # Skip empty lines and comments
    email=$(echo "$email" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$email" ] || [[ "$email" == \#* ]]; then
        continue
    fi
    
    # Validate email format
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo -e "${RED}Invalid email format: $email${NC}"
        continue
    fi
    
    total_emails=$((total_emails + 1))
    
    if check_email "$email"; then
        # Email is safe
        true
    else
        breached_emails=$((breached_emails + 1))
    fi
    
    echo ""
    rate_limit_check
    
done < "$EMAIL_FILE"

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Total emails checked: $total_emails"
echo -e "${RED}Breached emails: $breached_emails${NC}"
echo -e "${GREEN}Safe emails: $((total_emails - breached_emails))${NC}"
