#!/bin/bash

# macOS Low-Priority Throttle Control Setup Script
# This script automates the deployment of methods for managing
# debug.lowpri_throttle_enabled on macOS.
#
# DISCLAIMER: This setting is undocumented and intended for debugging.
# Modifying system behavior can have unintended consequences. Proceed with caution.



# --- Functions ---

# Function to deploy Method 1: Static Disable
deploy_static() {
    echo "--- Deploying Method 1: Disable Throttle on Startup ---"
    echo "Creating Launch Daemon plist file..."
    sudo tee /Library/LaunchDaemons/com.user.disablelowprithrottle.plist > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.disablelowprithrottle</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/sbin/sysctl</string>
        <string>debug.lowpri_throttle_enabled=0</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/disablethrottle.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/disablethrottle.err</string>
</dict>
</plist>
EOF

    if [ $? -eq 0 ]; then
        echo "Setting correct permissions..."
        sudo chown root:wheel /Library/LaunchDaemons/com.user.disablelowprithrottle.plist
        sudo chmod 644 /Library/LaunchDaemons/com.user.disablelowprithrottle.plist
        echo "Loading the daemon..."
        sudo launchctl load /Library/LaunchDaemons/com.user.disablelowprithrottle.plist
        echo ""
        echo "✅ SUCCESS: Method 1 has been deployed."
        echo "The throttle is now disabled and will remain so after restart."
    else
        echo "❌ ERROR: Failed to create the plist file. Please check your sudo permissions."
    fi
}

# Function to deploy Method 2: Dynamic Control
deploy_dynamic() {
    echo "--- Deploying Method 2: Dynamic Control (AC vs. Battery) ---"
    echo "Creating the monitoring script..."
    sudo tee /usr/local/bin/power_throttle_manager.sh > /dev/null <<'EOF'
#!/bin/bash

LOG_FILE="/var/log/power_throttle_manager.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Power Throttle Manager started."

while true; do
    if pmset -g ps | grep -q "AC Power"; then
        CURRENT_STATE=$(sysctl -n debug.lowpri_throttle_enabled)
        if [ "$CURRENT_STATE" -ne 0 ]; then
            log_message "On AC Power. Disabling throttle."
            sysctl debug.lowpri_throttle_enabled=0
        fi
    else
        CURRENT_STATE=$(sysctl -n debug.lowpri_throttle_enabled)
        if [ "$CURRENT_STATE" -ne 1 ]; then
            log_message "On Battery Power. Enabling throttle."
            sysctl debug.lowpri_throttle_enabled=1
        fi
    fi
    sleep 5
done
EOF

    if [ $? -eq 0 ]; then
        echo "Making the script executable..."
        sudo chmod +x /usr/local/bin/power_throttle_manager.sh

        echo "Creating Launch Daemon plist file for the script..."
        sudo tee /Library/LaunchDaemons/com.user.powerthrottlemgr.plist > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.powerthrottlemgr</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/power_throttle_manager.sh</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/powerthrottlemgr.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/powerthrottlemgr.err</string>
</dict>
</plist>
EOF

        if [ $? -eq 0 ]; then
            echo "Setting correct permissions..."
            sudo chown root:wheel /Library/LaunchDaemons/com.user.powerthrottlemgr.plist
            sudo chmod 644 /Library/LaunchDaemons/com.user.powerthrottlemgr.plist
            echo "Loading the daemon..."
            sudo launchctl load /Library/LaunchDaemons/com.user.powerthrottlemgr.plist
            echo ""
            echo "✅ SUCCESS: Method 2 has been deployed."
            echo "Throttle will now automatically disable on AC and enable on Battery."
            echo "Monitor the log with: tail -f /var/log/power_throttle_manager.log"
        else
            echo "❌ ERROR: Failed to create the daemon plist file."
        fi
    else
        echo "❌ ERROR: Failed to create the monitoring script. Please check your sudo permissions."
    fi
}

# Function to deploy Method 3: Temporary Disable
deploy_temporary_disable() {
    DURATION_SECONDS=3600 # 1 hour
    echo "--- Deploying Method 3: Temporary Disable for 1 Hour ---"

    # Check if the dynamic manager is running and stop it temporarily
    dynamic_was_running=0
    if sudo launchctl list | grep -q "com.user.powerthrottlemgr"; then
        echo "Dynamic manager is running. Pausing it for 1 hour..."
        dynamic_was_running=1
        sudo launchctl unload /Library/LaunchDaemons/com.user.powerthrottlemgr.plist
    fi

    # Set up a trap to catch Ctrl+C and restore state
    cleanup_on_interrupt() {
        echo ""
        echo "⚠️  Process interrupted by user."
        if [ "$dynamic_was_running" -eq 1 ]; then
            echo "Restarting the dynamic throttle manager..."
            sudo launchctl load /Library/LaunchDaemons/com.user.powerthrottlemgr.plist
        fi
        echo "Cleanup complete. Exiting."
        exit 1
    }
    trap cleanup_on_interrupt INT

    echo "Disabling throttle for $((DURATION_SECONDS / 60)) minutes..."
    sudo sysctl debug.lowpri_throttle_enabled=0

    # Countdown timer
    for ((i=$DURATION_SECONDS; i>0; i--)); do
        # Sleep for 1 second and print remaining time
        sleep 1
        # Use carriage return to overwrite the line
        printf "\rTime remaining: %02d:%02d:%02d" $((i/3600)) $((i%3600/60)) $((i%60))
    done
    printf "\n" # Newline after countdown finishes

    echo "1 hour has passed. Checking power source..."
    if pmset -g ps | grep -q "AC Power"; then
        echo "System is on AC Power. Leaving throttle disabled."
    else
        echo "System is on Battery. Re-enabling throttle..."
        sudo sysctl debug.lowpri_throttle_enabled=1
    fi

    # Restore the dynamic manager if it was running
    if [ "$dynamic_was_running" -eq 1 ]; then
        echo "Restarting the dynamic throttle manager..."
        sudo launchctl load /Library/LaunchDaemons/com.user.powerthrottlemgr.plist
    fi

    echo ""
    echo "✅ SUCCESS: Temporary disable period has ended."
    echo "System state has been restored."
}

# Function to remove all configurations
remove_all() {
    echo "--- Removing All Configurations ---"
    echo "Unloading daemons (if they exist)..."
    sudo launchctl unload /Library/LaunchDaemons/com.user.disablelowprithrottle.plist 2>/dev/null
    sudo launchctl unload /Library/LaunchDaemons/com.user.powerthrottlemgr.plist 2>/dev/null

    echo "Deleting plist files..."
    if [ -f "/Library/LaunchDaemons/com.user.disablelowprithrottle.plist" ]; then
        sudo rm /Library/LaunchDaemons/com.user.disablelowprithrottle.plist
        echo "  - Removed com.user.disablelowprithrottle.plist"
    fi
    if [ -f "/Library/LaunchDaemons/com.user.powerthrottlemgr.plist" ]; then
        sudo rm /Library/LaunchDaemons/com.user.powerthrottlemgr.plist
        echo "  - Removed com.user.powerthrottlemgr.plist"
    fi

    echo "Deleting monitoring script..."
    if [ -f "/usr/local/bin/power_throttle_manager.sh" ]; then
        sudo rm /usr/local/bin/power_throttle_manager.sh
        echo "  - Removed power_throttle_manager.sh"
    fi

    echo "Re-enabling low-priority throttle by default..."
    sudo sysctl debug.lowpri_throttle_enabled=1

    echo ""
    echo "✅ SUCCESS: All configurations have been removed."
    echo "The system has been reset to its default state."
}

# --- Main Menu Loop ---

while true; do
    clear
    echo "=========================================="
    echo "  macOS Throttle Control Setup Script"
    echo "=========================================="
    echo "  This script will modify system settings."
    echo "  Please choose an option:"
    echo ""
    echo "  1) Deploy Method 1: Disable Throttle on Startup"
    echo "  2) Deploy Method 2: Dynamic Control (AC vs. Battery)"
    echo "  3) Deploy Method 3: Temporary Disable (1 Hour)"
    echo "  4) Remove All Configurations & Reset to Default"
    echo "  5) Exit"
    echo "=========================================="
    read -p "Enter your choice [1-5]: " choice

    case $choice in
        1)
            deploy_static
            ;;
        2)
            deploy_dynamic
            ;;
        3)
            deploy_temporary_disable
            ;;
        4)
            remove_all
            ;;
        5)
            echo "Exiting script."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter a number between 1 and 5."
            ;;
    esac

    echo ""
    read -p "Press Enter to return to the menu..."
done
