#!/usr/bin/env python3
"""
Python Installation Check and Admin Command Runner
This script checks if Python is installed, installs it if missing, handles dependencies,
and can run commands with administrator privileges.
"""

import os
import sys
import subprocess
import ctypes
import urllib.request
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
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable, " ".join(sys.argv), None, 1
        )
        sys.exit(0)

def check_python_installed():
    """Check if Python is installed and available in PATH"""
    try:
        # Check if python command works
        result = subprocess.run(["python", "--version"], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"Python found: {result.stdout.strip()}")
            return True
    except (subprocess.SubprocessError, FileNotFoundError):
        pass
    
    try:
        # Check if python3 command works
        result = subprocess.run(["python3", "--version"], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"Python found: {result.stdout.strip()}")
            return True
    except (subprocess.SubprocessError, FileNotFoundError):
        pass
    
    return False

def download_file(url, filename):
    """Download a file from URL with progress indicator"""
    try:
        with urllib.request.urlopen(url) as response, open(filename, 'wb') as out_file:
            file_size = int(response.info().get('Content-Length', 0))
            downloaded = 0
            chunk_size = 8192
            
            print(f"Downloading: {os.path.basename(filename)}")
            while True:
                chunk = response.read(chunk_size)
                if not chunk:
                    break
                out_file.write(chunk)
                downloaded += len(chunk)
                if file_size > 0:
                    percent = downloaded * 100 // file_size
                    print(f"Progress: {percent}% ({downloaded}/{file_size} bytes)", end='\r')
            print("\nDownload completed!")
            return True
    except Exception as e:
        print(f"Download failed: {e}")
        return False

def install_python():
    """Download and install the latest version of Python for Windows"""
    print("Python not found. Installing the latest version...")
    
    # Get the latest Python download URL
    python_url = "https://www.python.org/ftp/python/latest/python-3.x-amd64.exe"
    
    # Try to get the actual latest version
    try:
        import json
        with urllib.request.urlopen("https://api.github.com/repos/python/cpython/git/refs/tags") as response:
            tags = json.loads(response.read().decode())
            # Get the latest version tag
            latest_tag = tags[-1]['ref'].replace('refs/tags/v', '')
            python_url = f"https://www.python.org/ftp/python/{latest_tag}/python-{latest_tag}-amd64.exe"
    except:
        # Fallback URL if we can't get the latest version
        python_url = "https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"
    
    # Create temporary directory for download
    temp_dir = tempfile.mkdtemp()
    installer_path = os.path.join(temp_dir, "python_installer.exe")
    
    # Download Python installer
    if not download_file(python_url, installer_path):
        print("Failed to download Python installer")
        shutil.rmtree(temp_dir)
        return False
    
    # Install Python silently with PATH addition
    print("Installing Python...")
    try:
        result = subprocess.run([
            installer_path, "/quiet", "InstallAllUsers=1", "PrependPath=1",
            "Include_test=0", "Include_doc=0", "Include_launcher=1"
        ], timeout=300, capture_output=True)
        
        if result.returncode == 0:
            print("Python installed successfully!")
            # Update current process PATH to include Python
            os.environ['PATH'] = get_updated_path()
            return True
        else:
            print(f"Python installation failed with return code: {result.returncode}")
            return False
    except subprocess.TimeoutExpired:
        print("Python installation timed out")
        return False
    except Exception as e:
        print(f"Error during Python installation: {e}")
        return False
    finally:
        # Clean up
        shutil.rmtree(temp_dir)

def get_updated_path():
    """Get the updated system PATH including Python installation"""
    # Common Python installation paths
    possible_paths = [
        os.path.join(os.environ.get('SystemDrive', 'C:'), 'Python312'),
        os.path.join(os.environ.get('SystemDrive', 'C:'), 'Python311'),
        os.path.join(os.environ.get('SystemDrive', 'C:'), 'Python310'),
        os.path.join(os.environ.get('SystemDrive', 'C:'), 'Python39'),
        os.path.join(os.environ.get('SystemDrive', 'C:'), 'Python38'),
        os.path.join(os.environ.get('SystemDrive', 'C:'), 'Program Files', 'Python312'),
        os.path.join(os.environ.get('SystemDrive', 'C:'), 'Program Files', 'Python311'),
        os.path.join(os.environ.get('SystemDrive', 'C:'), 'Program Files', 'Python310'),
        os.path.join(os.environ.get('SystemDrive', 'C:'), 'Program Files', 'Python39'),
        os.path.join(os.environ.get('SystemDrive', 'C:'), 'Program Files', 'Python38'),
    ]
    
    current_path = os.environ.get('PATH', '')
    for path in possible_paths:
        if os.path.exists(path) and path not in current_path:
            current_path = f"{path};{current_path}"
            script_path = os.path.join(path, 'Scripts')
            if os.path.exists(script_path) and script_path not in current_path:
                current_path = f"{script_path};{current_path}"
    
    return current_path

def install_dependencies():
    """Install required Python dependencies"""
    print("Installing required dependencies...")
    
    dependencies = [
        "pywin32==306",
        "psutil==5.9.6",
        "requests==2.31.0"
    ]
    
    for dep in dependencies:
        try:
            print(f"Installing {dep}...")
            result = subprocess.run([
                sys.executable, "-m", "pip", "install", dep
            ], capture_output=True, text=True, timeout=120)
            
            if result.returncode == 0:
                print(f"✓ Successfully installed {dep}")
            else:
                print(f"✗ Failed to install {dep}: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print(f"✗ Installation of {dep} timed out")
            return False
        except Exception as e:
            print(f"✗ Error installing {dep}: {e}")
            return False
    
    print("All dependencies installed successfully!")
    return True

def run_command_as_admin(command, wait=True):
    """
    Run a command with administrator privileges
    
    Args:
        command (str): Command to execute
        wait (bool): Wait for the command to complete
    
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        # Use ShellExecute to run with UAC elevation
        result = ctypes.windll.shell32.ShellExecuteW(
            None,                   # hwnd
            "runas",                # operation (runas = admin)
            "cmd.exe",              # executable
            f'/c {command}',        # parameters
            None,                   # working directory
            1                       # show command (1 = normal window)
        )
        
        if result <= 32:
            print(f"Failed to execute command with error code: {result}")
            return False
        
        return True
        
    except Exception as e:
        print(f"Error running command as admin: {e}")
        return False

def main():
    """Main function"""
    print("=== Python Installation Check and Admin Command Runner ===\n")
    
    # Request admin privileges if not already admin
    if not is_admin():
        run_elevated()
    
    # Check if Python is installed
    if not check_python_installed():
        if not install_python():
            print("Failed to install Python. Exiting.")
            input("Press Enter to exit...")
            sys.exit(1)
    
    # Install dependencies
    if not install_dependencies():
        print("Some dependencies failed to install. Continuing anyway...")
    
    # Main interactive loop
    while True:
        print("\n" + "="*50)
        print("Options:")
        print("1. Run a command with admin privileges")
        print("2. Check Python installation")
        print("3. Install/update dependencies")
        print("4. Exit")
        
        choice = input("\nEnter your choice (1-4): ").strip()
        
        if choice == "1":
            command = input("Enter command to run: ").strip()
            if command:
                print(f"Running: {command}")
                success = run_command_as_admin(command, wait=True)
                if success:
                    print("Command executed successfully!")
                else:
                    print("Failed to execute command.")
            else:
                print("No command entered.")
                
        elif choice == "2":
            if check_python_installed():
                print("✓ Python is installed and available")
            else:
                print("✗ Python is not installed")
                
        elif choice == "3":
            if install_dependencies():
                print("✓ Dependencies installed successfully")
            else:
                print("✗ Some dependencies failed to install")
                
        elif choice == "4":
            print("Goodbye!")
            break
            
        else:
            print("Invalid choice. Please try again.")

if __name__ == "__main__":
    main()
