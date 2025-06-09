#!/usr/bin/env python3
"""
Arch Linux Auto-Installer with Rich TUI
Provides a clean interface for pacman/yay installations while preserving interactivity
"""

import subprocess
import threading
import time
import queue
import sys
import select
import termios
import tty
from datetime import datetime
from typing import List, Optional

from rich.console import Console
from rich.layout import Layout
from rich.panel import Panel
from rich.live import Live
from rich.text import Text
from rich.align import Align


class ArchInstaller:
    def __init__(self):
        self.console = Console()
        self.layout = Layout()
        self.current_package = ""
        self.installation_status = "Ready"
        self.custom_logs = []
        self.pacman_output = []
        self.progress_total = 0
        self.progress_current = 0
        self.current_process: Optional[subprocess.Popen] = None

        # Input handling
        self.input_buffer = ""
        self.input_prompt = ""
        self.waiting_for_input = False
        self.input_queue = queue.Queue()

        # Terminal settings
        self.old_terminal_settings = None

        # Create layout structure
        self.setup_layout()

    def setup_layout(self):
        """Create the TUI layout structure"""
        # Split main layout: header, body, input
        self.layout.split_column(
            Layout(name="header", size=3),
            Layout(name="body"),
            Layout(name="input_area", size=5),  # Increased size for better visibility
        )

        # Split body into left panel (status + logs) and right panel (pacman output)
        self.layout["body"].split_row(
            Layout(name="left_panel", ratio=1), Layout(name="right_panel", ratio=2)
        )

        # Split left panel: status area and custom logs
        self.layout["left_panel"].split_column(
            Layout(name="status", size=8), Layout(name="logs")
        )

    def update_display(self):
        """Update all display areas"""
        # Header
        header_text = Text(
            "🔧 Arch Linux Auto-Installer", style="bold blue", justify="center"
        )
        self.layout["header"].update(Panel(header_text, style="blue"))

        # Status area
        status_content = Text()
        status_content.append("Installation Status\n", style="bold green")
        status_content.append(f"Current: {self.current_package or 'None'}\n")
        status_content.append(f"Status: {self.installation_status}\n")
        if self.progress_total > 0:
            progress_bar = "█" * int((self.progress_current / self.progress_total) * 20)
            progress_empty = "░" * (20 - len(progress_bar))
            progress_text = f"[{progress_bar}{progress_empty}] {self.progress_current}/{self.progress_total}"
            status_content.append(f"Progress: {progress_text}\n")
        self.layout["status"].update(
            Panel(status_content, title="Status", border_style="green")
        )

        # Custom logs area
        log_content = Text()
        recent_logs = self.custom_logs[-10:]  # Reduced to fit better
        for log in recent_logs:
            log_content.append(f"{log}\n")
        self.layout["logs"].update(
            Panel(log_content, title="Installation Log", border_style="yellow")
        )

        # Pacman output area
        pacman_content = Text()
        recent_output = self.pacman_output[-18:]  # Reduced to fit better
        for line in recent_output:
            pacman_content.append(f"{line}\n")
        self.layout["right_panel"].update(
            Panel(pacman_content, title="Pacman/Yay Output", border_style="cyan")
        )

        # Input area with cursor
        self.update_input_area()

    def update_input_area(self):
        """Update the input area with current input buffer and cursor"""
        if self.waiting_for_input:
            # Show prompt and input with cursor
            input_text = Text()
            input_text.append(f"{self.input_prompt}\n", style="bold yellow")
            input_text.append(f"> {self.input_buffer}", style="white")
            input_text.append("█", style="white on white")  # Cursor

            panel_style = "bold bright_white"
            border_style = "bright_yellow"
        else:
            # Show ready message
            input_text = Text(
                "Ready for next operation...", style="dim white", justify="center"
            )
            panel_style = "dim"
            border_style = "dim"

        self.layout["input_area"].update(
            Panel(
                input_text, title="Input", style=panel_style, border_style=border_style
            )
        )

    def setup_terminal(self):
        """Setup terminal for raw input"""
        if sys.stdin.isatty():
            self.old_terminal_settings = termios.tcgetattr(sys.stdin)
            tty.setraw(sys.stdin.fileno())

    def restore_terminal(self):
        """Restore terminal settings"""
        if self.old_terminal_settings:
            termios.tcsetattr(sys.stdin, termios.TCSADRAIN, self.old_terminal_settings)

    def get_char(self):
        """Get a single character from stdin (non-blocking)"""
        if sys.stdin.isatty() and select.select([sys.stdin], [], [], 0)[0]:
            char = sys.stdin.read(1)
            return char
        return None

    def handle_input(self, char):
        """Handle a single character input"""
        if char == "\r" or char == "\n":  # Enter
            result = self.input_buffer
            self.input_buffer = ""
            self.waiting_for_input = False
            self.input_queue.put(result)
            return True
        elif char == "\x7f" or char == "\x08":  # Backspace
            if self.input_buffer:
                self.input_buffer = self.input_buffer[:-1]
        elif char == "\x03":  # Ctrl+C
            raise KeyboardInterrupt
        elif char and ord(char) >= 32:  # Printable characters
            self.input_buffer += char

        return False

    def wait_for_input(self, prompt: str = "Enter your choice") -> str:
        """Wait for user input within the TUI"""
        self.input_prompt = prompt
        self.input_buffer = ""
        self.waiting_for_input = True

        while self.waiting_for_input:
            char = self.get_char()
            if char:
                self.handle_input(char)
            time.sleep(0.05)  # Small delay to prevent busy waiting

        try:
            return self.input_queue.get_nowait()
        except queue.Empty:
            return ""

    def add_log(self, message: str, log_type: str = "INFO"):
        """Add a message to custom logs"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_entry = f"[{timestamp}] {log_type}: {message}"
        self.custom_logs.append(log_entry)

    def add_pacman_output(self, line: str):
        """Add a line to pacman output"""
        if line.strip():  # Only add non-empty lines
            self.pacman_output.append(line.rstrip())

    def read_process_output(self, process: subprocess.Popen):
        """Read process output in a separate thread"""
        try:
            while True:
                if process.stdout:
                    line = process.stdout.readline()
                    if line:
                        self.add_pacman_output(line)
                    elif process.poll() is not None:
                        break
                time.sleep(0.1)
        except Exception as e:
            self.add_log(f"Error reading output: {e}", "ERROR")

    def install_package_interactive(self, package: str, use_yay: bool = False) -> bool:
        """Install a package with interactive input handling"""
        self.current_package = package
        self.installation_status = f"Installing {package}..."
        self.add_log(f"Starting installation of {package}")

        # Choose command
        if use_yay:
            cmd = ["yay", "-S", package]  # No --noconfirm for interactive mode
        else:
            cmd = [
                "sudo",
                "pacman",
                "-S",
                package,
            ]  # No --noconfirm for interactive mode

        try:
            # Start process with interactive capabilities
            self.current_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                stdin=subprocess.PIPE,
                text=True,
                bufsize=1,
            )

            # Start output reading thread
            output_thread = threading.Thread(
                target=self.read_process_output,
                args=(self.current_process,),
                daemon=True,
            )
            output_thread.start()

            # Monitor process and handle input requests
            while self.current_process.poll() is None:
                # Check if process needs input (very basic detection)
                if (
                    "Proceed with installation" in str(self.pacman_output[-5:])
                    or "Continue?" in str(self.pacman_output[-5:])
                    or "[Y/n]" in str(self.pacman_output[-5:])
                ):
                    user_input = self.wait_for_input(
                        "Pacman is asking for confirmation"
                    )
                    if not user_input:
                        user_input = "Y"  # Default to yes

                    self.current_process.stdin.write(f"{user_input}\n")
                    self.current_process.stdin.flush()

                time.sleep(0.5)

            return_code = self.current_process.wait()

            if return_code == 0:
                self.add_log(f"✓ Successfully installed {package}", "SUCCESS")
                self.installation_status = f"✓ {package} installed"
                return True
            else:
                self.add_log(
                    f"✗ Failed to install {package} (exit code: {return_code})", "ERROR"
                )
                self.installation_status = f"✗ {package} failed"
                return False

        except Exception as e:
            self.add_log(f"✗ Exception installing {package}: {e}", "ERROR")
            self.installation_status = f"✗ {package} error"
            return False
        finally:
            self.current_process = None

    def install_package_noconfirm(self, package: str, use_yay: bool = False) -> bool:
        """Install a package using --noconfirm (non-interactive)"""
        self.current_package = package
        self.installation_status = f"Installing {package}..."
        self.add_log(f"Starting installation of {package}")

        # Choose command with --noconfirm
        if use_yay:
            cmd = ["yay", "-S", "--noconfirm", package]
        else:
            cmd = ["sudo", "pacman", "-S", "--noconfirm", package]

        try:
            self.current_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )

            output_thread = threading.Thread(
                target=self.read_process_output,
                args=(self.current_process,),
                daemon=True,
            )
            output_thread.start()

            return_code = self.current_process.wait()
            time.sleep(0.5)

            if return_code == 0:
                self.add_log(f"✓ Successfully installed {package}", "SUCCESS")
                self.installation_status = f"✓ {package} installed"
                return True
            else:
                self.add_log(
                    f"✗ Failed to install {package} (exit code: {return_code})", "ERROR"
                )
                self.installation_status = f"✗ {package} failed"
                return False

        except Exception as e:
            self.add_log(f"✗ Exception installing {package}: {e}", "ERROR")
            self.installation_status = f"✗ {package} error"
            return False
        finally:
            self.current_process = None

    def install_packages(
        self, packages: List[str], use_yay: bool = False, interactive: bool = True
    ):
        """Install multiple packages"""
        self.progress_total = len(packages)
        self.progress_current = 0

        successful = 0
        failed = 0

        for i, package in enumerate(packages):
            self.progress_current = i
            self.update_display()

            # Choose installation method
            if interactive:
                success = self.install_package_interactive(package, use_yay)
            else:
                success = self.install_package_noconfirm(package, use_yay)

            if success:
                successful += 1
            else:
                failed += 1

            self.progress_current = i + 1
            self.update_display()
            time.sleep(1)

        self.current_package = ""
        self.installation_status = f"Complete: {successful} successful, {failed} failed"
        self.add_log(
            f"Installation complete: {successful}/{len(packages)} packages installed"
        )

    def run_installer(self, packages: List[str], aur_packages: List[str] = None):
        """Main installer routine"""
        try:
            self.setup_terminal()

            with Live(self.layout, refresh_per_second=10, screen=True):
                self.add_log("Arch Linux Auto-Installer started")
                self.update_display()

                # Ask for installation mode
                mode = self.wait_for_input("Use interactive mode? (Y/n)")
                interactive = mode.lower() != "n"

                if packages:
                    self.add_log(f"Installing {len(packages)} packages with pacman")
                    self.install_packages(
                        packages, use_yay=False, interactive=interactive
                    )

                if aur_packages:
                    self.add_log(
                        f"Installing {len(aur_packages)} AUR packages with yay"
                    )
                    self.install_packages(
                        aur_packages, use_yay=True, interactive=interactive
                    )

                self.current_package = ""
                self.installation_status = "All installations complete!"
                self.add_log("Installer finished successfully")
                self.update_display()

                self.wait_for_input("Press Enter to exit")

        except KeyboardInterrupt:
            self.add_log("Installation interrupted by user", "WARNING")
            if self.current_process:
                self.current_process.terminate()
        except Exception as e:
            self.add_log(f"Unexpected error: {e}", "ERROR")
        finally:
            self.restore_terminal()


def main():
    """Main entry point"""
    regular_packages = ["vim", "git", "htop", "neofetch"]

    aur_packages = [
        # "visual-studio-code-bin",
    ]

    installer = ArchInstaller()

    print("🔧 Arch Linux Auto-Installer")
    print("=" * 50)
    print(f"Will install {len(regular_packages)} regular packages")
    if aur_packages:
        print(f"Will install {len(aur_packages)} AUR packages")
    print("\nStarting installer...")
    time.sleep(2)

    try:
        installer.run_installer(regular_packages, aur_packages)
    except KeyboardInterrupt:
        print("\nInstallation cancelled.")
        sys.exit(1)


if __name__ == "__main__":
    main()
