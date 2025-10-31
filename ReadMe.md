


# How to Use the Script

1.  **Save the Script:**
    *   If you downloaded the file, you can skip this step.
    *   Open a plain text editor (like TextEdit, but make sure it's in plain text mode, or use a code editor like VS Code).
    *   Copy and paste the entire code block above into the editor.
    *   Save the file with a `.sh` extension, for example, `setup_throttle.sh` on your Desktop.

3.  **Make the Script Executable:**
    *   Open the **Terminal** app.
    *   Navigate to where you saved the file. For example, if it's on your Desktop:
        ```bash
        cd ~/Desktop
        ```
    *   Run the following command to make the script executable:
        ```bash
        chmod +x setup_throttle.sh
        ```

4.  **Run the Script:**
    *   In the same terminal window, run the script:
        ```bash
        ./setup_throttle.sh
        ```
    *   The script will launch, clear the screen, and display the menu. You will be prompted for your administrator password when the script executes commands with `sudo`.

5.  **Follow the On-Screen Menu:**
    *   Simply type `1`, `2`, `3`, `4`, or `5` and press Enter to perform the desired action.
    *   The script will provide feedback on what it's doing and confirm when it's finished.

This script provides a safe, reversible, and user-friendly way to manage the performance settings on your Mac.


**Temporary boost preformance when on battery**
1.  *   Re-run the script:
        ```bash
        ./setup_throttle.sh
        ```
2.  *   Select Option 3 from the menu.
3.  The script will:
    *   Check if Method 2 (Dynamic Control) is active. If so, it will pause it.
    *   Disable the throttle.
    *   Display a live countdown for one hour.
    *   After the hour, it will check if you're on battery. If you are, it re-enables the throttle.
    *   It will then restart Method 2 if it was previously running, restoring your normal automatic behavior.

You can also press `Ctrl+C` during the countdown, and the script will intelligently restart the dynamic manager for you before exiting. This makes it a very safe and robust way to get a temporary performance boost.
