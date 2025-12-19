# Dockge Update Checker Script

A lightweight Bash script designed as a companion for [Dockge](https://github.com/louislam/dockge). 

It automatically checks your Dockge stacks for available Docker image updates, cleans up old layers, and sends notifications (Discord, Telegram, Gotify, etc.), allowing you to keep your server clean and up-to-date without blindly restarting services.

## Why use this with Dockge?

Dockge is excellent for managing stacks, but you might want proactive notifications when an image update is available **before** you log in. This script:
1.  **Pulls** the latest images for all your stacks in the background.
2.  **Compares** the running version vs. the pulled version.
3.  **Notifies** you if there is a difference.
4.  **Cleans up** dangling images to prevent disk usage bloat.
5.  **Does NOT restart** your containers. You remain in control and use the Dockge UI to apply updates when you are ready.

## Installation

### 1. Download the script
Run this on the host machine where Dockge is installed.

```bash
# Example directory
mkdir -p /opt/scripts
cd /opt/scripts
git clone [https://github.com/YOUR_USERNAME/dockge-update-checker.git](https://github.com/YOUR_USERNAME/dockge-update-checker.git) .
chmod +x dockge-update-check.sh
