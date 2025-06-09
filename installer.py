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
from datetime import datetime
from typing import List, Optional

from rich.console import Console
from rich.layout import Layout
from rich.panel import Panel
from rich.live import Live
from rich.text import Text
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskID
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
        self.output_queue = queue.Queue()
        self.current_process: Optional[subprocess.Popen] = None

        # Create layout structure
        self.setup_layout()

    def setup_layout(self):
        """Create the TUI layout structure"""
        # Split main layout: header, body, footer
        self.layout.split_column(
            Layout(name="header", size=3),
            Layout(name="body"),
            Layout(name="input_area", size=3),
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
        recent_logs = self.custom_logs[-15:]  # Show last 15 entries
        for log in recent_logs:
            log_content.append(f"{log}\n")
        self.layout["logs"].update(
            Panel(log_content, title="Installation Log", border_style="yellow")
        )

        # Pacman output area
        pacman_content = Text()
        recent_output = self.pacman_output[-25:]  # Show last 25 lines
        for line in recent_output:
            pacman_content.append(f"{line}\n")
        self.layout["right_panel"].update(
            Panel(pacman_content, title="Pacman/Yay Output", border_style="cyan")
        )

        # Input area
        input_text = Text(
            "Enter your choice or press Enter to continue...", style="bold white"
        )
        self.layout["input_area"].update(Panel(Align.center(input_text), style="white"))

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
                # Read from stdout
                if process.stdout:
                    line = process.stdout.readline()
                    if line:
                        self.add_pacman_output(line)
                    elif process.poll() is not None:  # Process finished
                        break
                time.sleep(0.1)
        except Exception as e:
            self.add_log(f"Error reading output: {e}", "ERROR")

    def install_package(self, package: str, use_yay: bool = False) -> bool:
        """Install a package using pacman or yay"""
        self.current_package = package
        self.installation_status = f"Installing {package}..."
        self.add_log(f"Starting installation of {package}")

        # Choose command
        cmd = ["yay", "-S"] if use_yay else ["sudo", "pacman", "-S"]
        cmd.append(package)

        try:
            # Start process with pipes for output capture but preserve stdin
            self.current_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                stdin=None,  # Inherit stdin for interactivity
                text=True,
                bufsize=1,  # Line buffered
            )

            # Start thread to read output
            output_thread = threading.Thread(
                target=self.read_process_output,
                args=(self.current_process,),
                daemon=True,
            )
            output_thread.start()

            # Wait for process to complete
            return_code = self.current_process.wait()

            # Wait a bit for output thread to finish
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

    def install_packages(self, packages: List[str], use_yay: bool = False):
        """Install multiple packages"""
        self.progress_total = len(packages)
        self.progress_current = 0

        successful = 0
        failed = 0

        for i, package in enumerate(packages):
            self.progress_current = i

            # Update display before installation
            self.update_display()

            # Install package
            success = self.install_package(package, use_yay)

            if success:
                successful += 1
            else:
                failed += 1

            self.progress_current = i + 1
            self.update_display()

            # Small delay between packages
            time.sleep(1)

        # Final status
        self.current_package = ""
        self.installation_status = f"Complete: {successful} successful, {failed} failed"
        self.add_log(
            f"Installation complete: {successful}/{len(packages)} packages installed"
        )

    def run_installer(self, packages: List[str], aur_packages: List[str] = None):
        """Main installer routine"""
        try:
            with Live(self.layout, refresh_per_second=4, screen=True):
                self.add_log("Arch Linux Auto-Installer started")
                self.update_display()
                time.sleep(2)

                # Install regular packages
                if packages:
                    self.add_log(f"Installing {len(packages)} packages with pacman")
                    self.install_packages(packages, use_yay=False)

                # Install AUR packages
                if aur_packages:
                    self.add_log(
                        f"Installing {len(aur_packages)} AUR packages with yay"
                    )
                    self.install_packages(aur_packages, use_yay=True)

                # Final display
                self.current_package = ""
                self.installation_status = "All installations complete!"
                self.add_log("Installer finished successfully")
                self.update_display()

                # Keep display open for review
                input("\nPress Enter to exit...")

        except KeyboardInterrupt:
            self.add_log("Installation interrupted by user", "WARNING")
            if self.current_process:
                self.current_process.terminate()
        except Exception as e:
            self.add_log(f"Unexpected error: {e}", "ERROR")


def main():
    """Main entry point"""
    # Example package lists - customize these
    regular_packages = ["git", "base-devel"]

    aur_packages = [
        # "visual-studio-code-bin",
        # "yay"  # Don't include if yay is already installed
    ]

    installer = ArchInstaller()

    # Show intro
    print("🔧 Arch Linux Auto-Installer")
    print("=" * 50)
    print(f"Will install {len(regular_packages)} regular packages")
    if aur_packages:
        print(f"Will install {len(aur_packages)} AUR packages")
    print("\nPress Enter to start or Ctrl+C to cancel...")

    try:
        input()
        installer.run_installer(regular_packages, aur_packages)
    except KeyboardInterrupt:
        print("\nInstallation cancelled.")
        sys.exit(1)


if __name__ == "__main__":
    main()
