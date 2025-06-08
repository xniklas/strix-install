## Implementation Plan

### 1. Script Structure

```
├── config/
│   ├── packages.conf     # Package lists by category
│   ├── services.conf     # Services to enable
│   └── gpu-drivers.conf  # GPU-specific packages
├── lib/
│   ├── colors.sh         # Color definitions
│   ├── progress.sh       # Progress bar functions
│   ├── logging.sh        # Log management
│   └── utils.sh          # Helper functions
└── install.sh            # Main script
```

### 2. Core Functions Needed

- **Requirement checker**: Check for pacman, yay, internet, disk space, required packages (base-devel, git, yadm), enable multilib, handle if script is exec by sudo (not allowed)
- **Progress bar**: Custom function that updates during package installs
- **Package installer**: Wrapper around pacman/yay with output redirection
- **Service manager**: Enable/start systemd services
- **GPU detector**: Hardware detection + user selection
- **Config writer**: Handle dotfiles and system configs
- **Stats tracker**: Count packages, time operations, log failures

### 3. Key Implementation Details

- Use `tput` for colors and cursor control
- Redirect pacman/yay output to `/dev/null` or log files
- Use `pv` or custom spinner for progress indication
- Store failed packages in array for final report
- Use `systemctl` for service management
- Implement rollback mechanism for critical failures

### 4. Flow

1. **Pre-flight** → Requirements + system info + get dotfiles via yadm clone <https://github.com/xniklas/dotfiles.git>
2. **Configuration** → GPU selection + package customization  
3. **Installation** → Packages with progress tracking
4. **Configuration** → uwsm, system settings
5. **Services** → Enable/start required services
6. **Optimization** → Cache, indexing, tweaks
7. **Report** → Stats, failures, next steps
