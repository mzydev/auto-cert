#!/bin/bash

# ===================== LOGO =====================
show_logo() {
    clear
    echo -e "\e[1;36m============================================================\e[0m"
    echo -e "\e[1;34m
        █████╗ ██╗   ██╗████████╗ ██████╗      ██████╗███████╗██████╗ ████████╗
       ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗    ██╔════╝██╔════╝██╔══██╗╚══██╔══╝
       ███████║██║   ██║   ██║   ██║   ██║    ██║     █████╗  ██████╔╝   ██║   
       ██╔══██║██║   ██║   ██║   ██║   ██║    ██║     ██╔══╝  ██╔══██╗   ██║   
       ██║  ██║╚██████╔╝   ██║   ╚██████╔╝    ╚██████╗███████╗██║  ██║   ██║   
       ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝      ╚═════╝╚══════╝╚═╝  ╚═╝   ╚═╝   
    \e[0m"
    echo -e "\e[1;36m============================================================\e[0m"
    echo -e "\e[1;32m                 🔰  AutoCert Multi SSL Manager 🔰\e[0m"
    echo -e "\e[1;36m============================================================\e[0m\n"
}

# ===================== SELECT MANAGER =====================
select_manager() {
    show_logo
    echo -e "Select your manager type:\n"
    echo -e "1) Pasarguard SSL Manager"
    echo -e "2) Marzneshin SSL Manager"
    echo -e "3) Marzban SSL Manager"
    echo -e "4) Exit"
    echo -e "\e[1;36m============================================================\e[0m"
    read -p "Enter choice [1-4]: " manager_choice

    case $manager_choice in
        1)
            MANAGER_NAME="Pasarguard"
            CERT_PATH="/var/lib/pasarguard/certs"
            ENV_FILE="/opt/pasarguard/.env"
            SERVICE_NAME="pasarguard"
            ;;
        2)
            MANAGER_NAME="Marzneshin"
            CERT_PATH="/var/lib/marzneshin/certs"
            ENV_FILE="/opt/marzneshin/.env"
            SERVICE_NAME="marzneshin"
            ;;
        3)
            MANAGER_NAME="Marzban"
            CERT_PATH="/var/lib/marzban/certs"
            ENV_FILE="/opt/marzban/.env"
            SERVICE_NAME="marzban"
            ;;
        4)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "\e[1;31mInvalid option. Try again.\e[0m"
            sleep 1
            select_manager
            ;;
    esac
}

# Call selection menu
select_manager

BORDER="============================================================"

# ===================== MAIN MENU =====================
show_menu() {
    clear
    echo -e "\e[1;36m$BORDER\e[0m"
    echo -e "\e[1;32m        🛡️  $MANAGER_NAME SSL Manager (AutoCert 0.1)\e[0m"
    echo -e "\e[1;36m$BORDER\e[0m"
    echo -e "\e[1;32mTelegram:@DVHOST_CLOUD | YouTube: youtube.com/@dvhost_cloud\e[0m"
    echo -e "\e[1;36m$BORDER\e[0m"
    echo -e "1) Install new SSL"
    echo -e "2) Manage existing SSLs"
    echo -e "3) Remove SSL manually"
    echo -e "4) Change Manager"
    echo -e "5) Exit"
    echo -e "\e[1;36m$BORDER\e[0m"
    echo -n "Enter choice [1-5]: "
}

# ===================== INSTALL SSL =====================
install_ssl() {
    echo -e "\n\e[1;33m--- SSL Installation for $MANAGER_NAME ---\e[0m"
    read -p "Enter domain (e.g. example.com): " domain
    read -p "Enter email address: " email

    if [ -z "$domain" ] || [ -z "$email" ]; then
        echo -e "\e[1;31m[!] Domain and email are required!\e[0m"
        return
    fi

    echo -e "\n\e[1;34m[+] Installing Certbot if needed...\e[0m"
    sudo apt update -y >/dev/null 2>&1
    sudo apt install -y certbot >/dev/null 2>&1

    echo -e "\n\e[1;34m[+] Generating SSL for $domain ...\e[0m"
    sudo certbot certonly --standalone -d "$domain" -m "$email" --agree-tos --non-interactive

    SRC_CERT="/etc/letsencrypt/live/$domain/fullchain.pem"
    SRC_KEY="/etc/letsencrypt/live/$domain/privkey.pem"

    if [ ! -f "$SRC_CERT" ] || [ ! -f "$SRC_KEY" ]; then
        echo -e "\e[1;31m[!] SSL generation failed! Check domain or DNS.\e[0m"
        return
    fi

    echo -e "\n\e[1;34m[+] Copying certificates to $CERT_PATH ...\e[0m"
    sudo mkdir -p "$CERT_PATH"
    sudo cp "$SRC_CERT" "$CERT_PATH/fullchain.pem"
    sudo cp "$SRC_KEY" "$CERT_PATH/privkey.pem"

    # Update .env per manager
    if [ -f "$ENV_FILE" ]; then
        echo -e "\n\e[1;34m[+] Updating .env configuration for $MANAGER_NAME...\e[0m"

        case $MANAGER_NAME in
            "Pasarguard")
                sudo sed -i -E "s|^#?[[:space:]]*UVICORN_SSL_CERTFILE[[:space:]]*=.*|UVICORN_SSL_CERTFILE = \"$CERT_PATH/fullchain.pem\"|g" "$ENV_FILE"
                sudo sed -i -E "s|^#?[[:space:]]*UVICORN_SSL_KEYFILE[[:space:]]*=.*|UVICORN_SSL_KEYFILE = \"$CERT_PATH/privkey.pem\"|g" "$ENV_FILE"
                ;;
            "Marzneshin"|"Marzban")
                sudo sed -i -E "s|^#?[[:space:]]*SSL_CERT_FILE[[:space:]]*=.*|SSL_CERT_FILE=\"$CERT_PATH/fullchain.pem\"|g" "$ENV_FILE"
                sudo sed -i -E "s|^#?[[:space:]]*SSL_KEY_FILE[[:space:]]*=.*|SSL_KEY_FILE=\"$CERT_PATH/privkey.pem\"|g" "$ENV_FILE"
                ;;
        esac
        echo -e "\e[1;32m[✓] .env updated successfully for $MANAGER_NAME.\e[0m"
    else
        echo -e "\e[1;31m[!] .env file not found at $ENV_FILE — skipping update.\e[0m"
    fi

    # Restart service
    if [ -f "$CERT_PATH/fullchain.pem" ] && [ -f "$CERT_PATH/privkey.pem" ]; then
        echo -e "\n\e[1;32m$BORDER\e[0m"
        echo -e "\e[1;32m✅ SSL Installed Successfully for $MANAGER_NAME!\e[0m"
        echo -e "\e[1;36mDomain :\e[0m $domain"
        echo -e "\e[1;36mEmail  :\e[0m $email"
        echo -e "\e[1;36mCerts  :\e[0m"
        echo -e "  $CERT_PATH/fullchain.pem"
        echo -e "  $CERT_PATH/privkey.pem"
        echo -e "\e[1;32m$BORDER\e[0m"

        echo -ne "\nDo you want to restart $MANAGER_NAME service? (y/n): "
        read restart_choice
        if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
            echo -e "\e[1;34m[+] Restarting $SERVICE_NAME service...\e[0m"
            sudo systemctl restart "$SERVICE_NAME"
            echo -e "\e[1;32m[✓] $MANAGER_NAME service restarted successfully.\e[0m"
        else
            echo -e "\e[1;33m[-] Skipped restart.\e[0m"
        fi
    else
        echo -e "\e[1;31m[!] Copy failed, certificates not found.\e[0m"
    fi
}

# ===================== MANAGE SSL =====================
manage_ssl() {
    echo -e "\n\e[1;33m--- Existing SSL Certificates ---\e[0m"
    SSL_DIR="/etc/letsencrypt/live"
    certs=()
    for dir in "$SSL_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/fullchain.pem" ]; then
            certs+=("$(basename "$dir")")
        fi
    done

    count=${#certs[@]}
    if [ $count -eq 0 ]; then
        echo -e "\e[1;31m[!] No valid SSL certificates found.\e[0m"
        return
    fi

    echo -e "\nAvailable SSLs:"
    for i in "${!certs[@]}"; do
        echo "[$((i+1))] ${certs[$i]}"
    done
    echo "[0] Back to main menu"

    echo -ne "\nSelect SSL to manage: "
    read choice

    if [ "$choice" == "0" ]; then
        return
    fi

    index=$((choice-1))
    if [ $index -ge 0 ] && [ $index -lt $count ]; then
        domain="${certs[$index]}"
        echo -e "\n\e[1;36mSelected: $domain\e[0m"
        echo "1) Renew SSL"
        echo "2) Remove SSL"
        echo "3) Back"
        read -p "Choose action: " action

        case $action in
            1)
                echo -e "\e[1;34m[+] Renewing SSL for $domain...\e[0m"
                sudo certbot renew --cert-name "$domain"
                ;;
            2)
                echo -e "\e[1;31m[!] Removing SSL for $domain...\e[0m"
                sudo certbot delete --cert-name "$domain"
                ;;
            *)
                echo "Back to menu."
                ;;
        esac
    else
        echo -e "\e[1;31mInvalid choice.\e[0m"
    fi
}

# ===================== REMOVE SSL =====================
remove_ssl() {
    echo -e "\n\e[1;33m--- Remove SSL Manually ---\e[0m"
    read -p "Enter domain to remove: " domain
    if [ -z "$domain" ]; then
        echo -e "\e[1;31m[!] Domain is required.\e[0m"
        return
    fi
    sudo certbot delete --cert-name "$domain"
    sudo rm -rf "$CERT_PATH"
    echo -e "\e[1;32m[✓] SSL removed for $domain and local certs deleted.\e[0m"
}

# ===================== MAIN LOOP =====================
while true; do
    show_menu
    read choice
    case $choice in
        1) install_ssl ;;
        2) manage_ssl ;;
        3) remove_ssl ;;
        4) select_manager ;; # change manager
        5) echo "Goodbye!"; exit 0 ;;
        *) echo -e "\e[1;31mInvalid option!\e[0m"; sleep 1 ;;
    esac
    echo -e "\nPress Enter to return to menu..."
    read
done
