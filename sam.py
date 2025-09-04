#!/usr/bin/env python3
"""
Simple script to run commands as administrator
"""

import os
import sys
import subprocess
import ctypes

def is_admin():
    """Check if running as administrator"""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_command_as_admin(command):
    """Run a command with administrator privileges"""
    if not is_admin():
        # Re-run the script with admin rights
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable, f'"{sys.argv[0]}" "{command}"', None, 1
        )
        sys.exit(0)
    else:
        # Already admin, run the command
        try:
            result = subprocess.run(command, shell=True, capture_output=True, text=True)
            print(f"Command: {command}")
            print(f"Return code: {result.returncode}")
            print(f"Output:\n{result.stdout}")
            if result.stderr:
                print(f"Errors:\n{result.stderr}")
        except Exception as e:
            print(f"Error executing command: {e}")

def main():
    if len(sys.argv) > 1:
        # Command provided as argument
        command = " ".join(sys.argv[1:])
        run_command_as_admin(command)
    else:
        # Interactive mode
        print("Python Admin Command Runner")
        print("=" * 30)
        
        while True:
            command = input("\nEnter command to run as admin (or 'exit' to quit): ").strip()
            
            if command.lower() in ['exit', 'quit']:
                break
                
            if command:
                run_command_as_admin(command)
            else:
                print("Please enter a valid command.")

if __name__ == "__main__":
    main()
