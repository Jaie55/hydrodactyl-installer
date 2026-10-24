#!/usr/bin/env bash
# shellcheck shell=bash
# English messages.

MSG[msg_root_required]="This installer must be run as root (try: sudo bash install.sh)."
MSG[msg_os]="Detected %s (%s), architecture %s."
MSG[msg_family]="Package family: %s."
MSG[msg_invalid_choice]="Invalid choice."
MSG[msg_downloading]="Downloading %s"
MSG[msg_press_enter]="Press Enter to continue..."

# Language menu
MSG[lang_title]="Choose language / Elige idioma"
MSG[lang_prompt]="Language"

# Main menu
MSG[menu_title]="What do you want to install?"
MSG[menu_panel_docker]="Panel only (Docker, recommended)"
MSG[menu_panel_native]="Panel only (native, Ubuntu/Debian)"
MSG[menu_panel_daemon]="Panel + daemon (Docker panel, native daemon)"
MSG[menu_daemon_wings]="Daemon only (Pterodactyl Wings)"
MSG[menu_daemon_elytra]="Daemon only (Elytra)"
MSG[menu_quit]="Quit"
MSG[menu_choice]="Select an option"

# Source
MSG[source_title]="Which panel version do you want?"
MSG[source_stable]="Latest stable release"
MSG[source_canary]="Canary (main branch)"
MSG[source_custom]="Custom fork (GitHub URL + branch/tag)"
MSG[prompt_source_choice]="Select a version"
MSG[prompt_repo_url]="Repository URL (e.g. https://github.com/user/hydrodactyl)"
MSG[prompt_repo_ref]="Branch or tag"
MSG[msg_source_stable]="Using the latest stable release (%s)."
MSG[msg_source_canary]="Using the canary branch (main)."
MSG[msg_source_custom]="Using %s at %s."
MSG[err_no_tags]="Could not find any release tag for the panel repository."
MSG[msg_nothing_to_do]="Nothing to do: pass --panel and/or --daemon, or run without arguments for the menu."
MSG[err_mode_required]="Choose --docker or --native."
MSG[msg_native_only_debian]="Native installs support Ubuntu/Debian only (detected %s). Use --docker."

# Prompts
MSG[prompt_domain]="Panel domain (e.g. panel.example.com)"
MSG[prompt_panel_dir]="Panel directory"
MSG[prompt_db]="Database engine"
MSG[prompt_ssl]="Request a free HTTPS certificate with Let's Encrypt?"
MSG[prompt_le_email]="Email for Let's Encrypt"
MSG[confirm_install]="Ready to install. Continue?"

# Docker
MSG[msg_docker_missing]="Docker or Docker Compose is not installed."
MSG[confirm_install_docker]="Install Docker now?"
MSG[msg_docker_installing]="Installing Docker..."
MSG[msg_docker_compose]="Fetching the docker-compose file..."
MSG[msg_docker_filling]="Filling in the compose configuration..."
MSG[msg_docker_starting]="Starting the panel containers..."
MSG[msg_docker_started]="Panel containers are up."
MSG[msg_docker_source_ignored]="Docker mode always runs the published stable image; the selected source only affects the compose file."
MSG[msg_docker_reuse]="Reusing the existing compose file at %s."

# Native
MSG[msg_apt_deps]="Installing system packages..."
MSG[msg_php_ppa]="Adding the PHP repository (ondrej/php)..."
MSG[msg_php]="Installing PHP 8.4 and extensions..."
MSG[msg_node]="Installing Node.js and pnpm..."
MSG[msg_composer]="Installing Composer..."
MSG[msg_db_creating]="Creating the database and user..."
MSG[msg_env]="Configuring the environment file..."
MSG[msg_key]="Generating the application key..."
MSG[msg_migrate]="Running database migrations..."
MSG[msg_perms]="Setting file permissions..."
MSG[msg_nginx]="Configuring nginx..."
MSG[msg_ssl]="Requesting the HTTPS certificate..."
MSG[msg_cron]="Adding the scheduler cronjob..."
MSG[msg_queue]="Creating the queue worker service..."
MSG[msg_verify]="Verifying the installation..."
MSG[msg_verify_skipped]="Skipping the panel check (--no-verify)."
MSG[msg_ssl_local]="Let's Encrypt needs a public domain; skipping the certificate for %s."
MSG[msg_verify_hint]="The panel is not answering at %s yet. Check the nginx/PHP-FPM or Docker logs; for local tests add the domain to /etc/hosts on the client machine."

# Daemon
MSG[msg_daemon_installing]="Installing the %s daemon..."
MSG[msg_proc_docker]="Installing Docker..."
MSG[msg_daemon_binary]="Downloading the %s binary..."
MSG[msg_daemon_service]="Creating the systemd service..."
MSG[msg_daemon_started]="The %s service is running."
MSG[prompt_daemon_config_path]="Path to the node config file downloaded from the panel (leave empty to paste it after)"
MSG[err_daemon_config_missing]="Config file not found: %s"
MSG[err_daemon_arch]="The %s daemon ships amd64/arm64 binaries only (detected %s)."
MSG[msg_daemon_config_hint]="Paste the node configuration from the panel into %s and run 'systemctl restart %s'."

# Finish
MSG[msg_done]="All done."
MSG[msg_panel_url]="Your panel should be available at %s"
MSG[msg_log]="Full log: %s"
MSG[err_download]="Failed to download %s"
