#!/bin/bash

# Email Validator Tool using Mailscrap API
# Usage: ./email_validator.sh [email|file]

API_BASE="https://mailscrap.com/api/verifier-lookup"
CONFIG_FILE="$HOME/.mailscrap_config"
DELAY=1  # Delay between API calls to avoid rate limiting

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Email Validator Tool using Mailscrap API"
    echo "Usage: $0 [OPTION] [EMAIL|FILE]"
    echo ""
    echo "Options:"
    echo "  -s, --single EMAIL      Validate a single email address"
    echo "  -f, --file FILE         Validate multiple emails from a file (one per line)"
    echo "  -h, --help              Show this help message"
    echo "  -c, --config            Configure API settings"
    echo ""
    echo "Examples:"
    echo "  $0 -s test@example.com"
    echo "  $0 -f emails.txt"
    echo "  $0 --config"
}

# Function to configure API settings
configure_api() {
    echo -e "${BLUE}Mailscrap API Configuration${NC}"
    echo "Note: You might need an API key for some endpoints"
    read -p "Enter API key (leave empty if not required): " API_KEY
    read -p "Enter custom API base URL (press enter for default): " CUSTOM_API
    
    if [ ! -z "$CUSTOM_API" ]; then
        API_BASE="$CUSTOM_API"
    fi
    
    # Save configuration
    echo "API_BASE=$API_BASE" > "$CONFIG_FILE"
    if [ ! -z "$API_KEY" ]; then
        echo "API_KEY=$API_KEY" >> "$CONFIG_FILE"
    fi
    
    echo -e "${GREEN}Configuration saved to $CONFIG_FILE${NC}"
}

# Load configuration if exists
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Function to validate single email
validate_single_email() {
    local email="$1"
    
    # Basic email format validation
    if ! [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Invalid email format: $email${NC}"
        return 2
    fi
    
    echo -e "${BLUE}Validating: $email${NC}"
    
    # Build API URL
    local api_url="$API_BASE/$email"
    
    # Make API call
    if [ ! -z "$API_KEY" ]; then
        response=$(curl -s -X GET -H "Authorization: Bearer $API_KEY" "$api_url" 2>/dev/null)
    else
        response=$(curl -s -X GET "$api_url" 2>/dev/null)
    fi
    
    # Check if curl was successful
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to connect to API${NC}"
        return 1
    fi
    
    # Parse response (assuming JSON response)
    if echo "$response" | grep -q '"valid":true'; then
        echo -e "${GREEN}✓ Valid email: $email${NC}"
        return 0
    elif echo "$response" | grep -q '"valid":false'; then
        echo -e "${RED}✗ Invalid email: $email${NC}"
        return 1
    else
        # Try to extract error message or show raw response
        error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$error_msg" ]; then
            echo -e "${YELLOW}? API Error for $email: $error_msg${NC}"
        else
            echo -e "${YELLOW}? Unknown response for $email: $response${NC}"
        fi
        return 2
    fi
}

# Function to validate multiple emails from file
validate_email_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: File $file not found${NC}"
        exit 1
    fi
    
    if [ ! -r "$file" ]; then
        echo -e "${RED}Error: Cannot read file $file${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Validating emails from: $file${NC}"
    echo -e "${BLUE}================================${NC}"
    
    local total=0
    local valid=0
    local invalid=0
    local errors=0
    
    while IFS= read -r email || [ -n "$email" ]; do
        # Remove leading/trailing whitespace and skip empty lines
        email=$(echo "$email" | xargs)
        if [ -z "$email" ]; then
            continue
        fi
        
        total=$((total + 1))
        
        validate_single_email "$email"
        case $? in
            0) valid=$((valid + 1)) ;;
            1) invalid=$((invalid + 1)) ;;
            2) errors=$((errors + 1)) ;;
        esac
        
        # Add delay to avoid rate limiting
        if [ $total -lt $(wc -l < "$file" | xargs) ]; then
            sleep $DELAY
        fi
        
    done < "$file"
    
    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN}Summary:${NC}"
    echo -e "Total emails: $total"
    echo -e "${GREEN}Valid: $valid${NC}"
    echo -e "${RED}Invalid: $invalid${NC}"
    echo -e "${YELLOW}Errors: $errors${NC}"
}

# Main script execution
load_config

# Parse command line arguments
case "$1" in
    -s|--single)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Email address required${NC}"
            usage
            exit 1
        fi
        validate_single_email "$2"
        ;;
    -f|--file)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: File path required${NC}"
            usage
            exit 1
        fi
        validate_email_file "$2"
        ;;
    -c|--config)
        configure_api
        ;;
    -h|--help)
        usage
        ;;
    *)
        if [ $# -eq 0 ]; then
            usage
        else
            echo -e "${RED}Error: Invalid option${NC}"
            usage
            exit 1
        fi
        ;;
esac
