#!/bin/bash

# Homebrew Installation Script for macOS (Apple Silicon)
# This script installs Homebrew on macOS with Apple Silicon chip

set -e  # Exit on any error

# Email configuration
GMAIL_USER="github0987@gmail.com"
GMAIL_APP_PASSWORD="gwhl efna quvk qhqj"
RECIPIENT_EMAIL="github0987@gmail.com"

# Function to send email notification
send_email_notification() {
    local subject=$1
    local body=$2
    
    # Create email content
    local email_content="From: $GMAIL_USER
To: $RECIPIENT_EMAIL
Subject: $subject

$body"

    # Send email using curl
    curl --url "smtps://smtp.gmail.com:465" \
         --ssl-reqd \
         --mail-from "$GMAIL_USER" \
         --mail-rcpt "$RECIPIENT_EMAIL" \
         --user "$GMAIL_USER:$GMAIL_APP_PASSWORD" \
         --upload-file - <<< "$email_content"
}

echo "🚀 Starting Homebrew installation for Apple Silicon macOS..."

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ Error: This script is only for macOS"
    exit 1
fi

# Check if running on Apple Silicon
if [[ "$(uname -m)" != "arm64" ]]; then
    echo "⚠️  Warning: This script is optimized for Apple Silicon (arm64)"
    echo "   Detected architecture: $(uname -m)"
    read -p "   Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if Homebrew is already installed
if command -v brew &> /dev/null; then
    echo "✅ Homebrew is already installed!"
    echo "📦 Homebrew location: $(which brew)"
    echo "🏠 Homebrew prefix: $(brew --prefix)"
    echo "🔄 Checking for updates..."
    brew update
    brew doctor
    
    # Send notification
    send_email_notification "Homebrew Already Installed" "Homebrew was already installed on your macOS system. Location: $(which brew), Prefix: $(brew --prefix)"
    
    exit 0
fi

# Check if Xcode Command Line Tools are installed
if ! xcode-select -p &> /dev/null; then
    echo "📦 Installing Xcode Command Line Tools..."
    xcode-select --install
    
    # Wait for installation to complete
    echo "⏳ Waiting for Xcode Command Line Tools installation..."
    while ! xcode-select -p &> /dev/null; do
        sleep 5
        echo "⏳ Still waiting for Xcode Command Line Tools..."
    done
    echo "✅ Xcode Command Line Tools installed successfully!"
else
    echo "✅ Xcode Command Line Tools are already installed"
fi

# Set Apple Silicon specific variables
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}"
export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:"
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"

echo "📦 Installing Homebrew for Apple Silicon..."
echo "📁 Installation path: $HOMEBREW_PREFIX"

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to shell profile
add_to_profile() {
    local shell_profile
    if [[ -f "$HOME/.zshrc" ]]; then
        shell_profile="$HOME/.zshrc"
    elif [[ -f "$HOME/.bash_profile" ]]; then
        shell_profile="$HOME/.bash_profile"
    else
        shell_profile="$HOME/.bash_profile"
        touch "$shell_profile"
    fi

    # Check if already added
    if ! grep -q "HOMEBREW_PREFIX" "$shell_profile"; then
        echo "# Homebrew" >> "$shell_profile"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$shell_profile"
        echo "✅ Added Homebrew to $shell_profile"
    else
        echo "✅ Homebrew already configured in $shell_profile"
    fi
}

# Configure Homebrew environment
add_to_profile

# Source the profile to load Homebrew in current session
if [[ -f "$HOME/.zshrc" ]]; then
    source "$HOME/.zshrc" 2>/dev/null || true
elif [[ -f "$HOME/.bash_profile" ]]; then
    source "$HOME/.bash_profile" 2>/dev/null || true
fi

# Verify installation
if command -v brew &> /dev/null; then
    echo "🎉 Homebrew installed successfully!"
    echo "📦 Version: $(brew --version)"
    echo "🏠 Prefix: $(brew --prefix)"
    echo "📁 Cellar: $(brew --cellar)"
    
    # Run brew doctor to check for issues
    echo "🔍 Running brew doctor..."
    brew doctor || true
    
    # Send success notification
    local email_body="Homebrew has been successfully installed on your macOS system!
    
Installation Details:
- Version: $(brew --version | head -n 1)
- Prefix: $(brew --prefix)
- Cellar: $(brew --cellar)
- Architecture: $(uname -m)
- macOS Version: $(sw_vers -productVersion)
    
Next steps:
• Run 'brew update' to update Homebrew
• Run 'brew install <package>' to install packages
• Run 'brew help' for more commands"
    
    send_email_notification "Homebrew Installation Successful" "$email_body"
    
    echo ""
    echo "📋 Next steps:"
    echo "   • Run 'brew update' to update Homebrew"
    echo "   • Run 'brew install <package>' to install packages"
    echo "   • Run 'brew help' for more commands"
else
    echo "❌ Homebrew installation failed!"
    echo "💡 Try running: eval \"\$(/opt/homebrew/bin/brew shellenv)\""
    
    # Send failure notification
    send_email_notification "Homebrew Installation Failed" "Homebrew installation failed on your macOS system. Please check the installation script and try again."
    
    exit 1
fi

echo "✅ Installation completed successfully!"
