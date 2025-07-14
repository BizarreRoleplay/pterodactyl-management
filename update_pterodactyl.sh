#!/bin/bash

# Variables
PANEL_DIR="/var/www/pterodactyl"
BACKUP_DIR="$PANEL_DIR/backups"
DATE=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/var/log/pterodactyl_management.log"
ENV_FILE="$PANEL_DIR/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

# Backup function
backup_panel() {
    log_message "${BLUE}🔄 Creating backup...${NC}"
    mkdir -p "$BACKUP_DIR"
    if tar czf "$BACKUP_DIR/panel_backup_$DATE.tar.gz" -C "$PANEL_DIR" .; then
        log_message "${GREEN}✅ Backup created: panel_backup_$DATE.tar.gz${NC}"
    else
        log_message "${RED}❌ Backup failed${NC}"
        return 1
    fi
}

# Update panel function
update_panel() {
    log_message "${BLUE}🔧 Starting Pterodactyl Panel update...${NC}"
    
    cd "$PANEL_DIR" || exit
    
    # Download and extract latest release
    log_message "${BLUE}📥 Downloading latest release...${NC}"
    if curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv; then
        log_message "${GREEN}✅ Download completed${NC}"
    else
        log_message "${RED}❌ Download failed${NC}"
        return 1
    fi
    
    # Set permissions
    chmod -R 755 storage/* bootstrap/cache
    
    # Install dependencies
    log_message "${BLUE}📦 Installing dependencies...${NC}"
    composer install --no-dev --optimize-autoloader
    
    # Run database migrations
    log_message "${BLUE}🗄️ Running database migrations...${NC}"
    php artisan migrate --seed --force
    
    # Clear and cache configs
    log_message "${BLUE}🧹 Clearing and caching configs...${NC}"
    php artisan view:clear
    php artisan config:clear
    php artisan config:cache
    php artisan route:cache
    
    # Set permissions
    chown -R www-data:www-data "$PANEL_DIR"
    
    log_message "${GREEN}✅ Pterodactyl Panel updated successfully!${NC}"
}

# Restart services
restart_services() {
    log_message "${BLUE}🔄 Restarting services...${NC}"
    systemctl restart nginx
    systemctl restart php8.1-fpm
    systemctl restart redis-server
    systemctl restart pterodactyl
    log_message "${GREEN}✅ Services restarted${NC}"
}

# Check system status
check_status() {
    log_message "${BLUE}📊 System Status Check${NC}"
    echo "=================================="
    
    # Check services
    services=("nginx" "php8.1-fpm" "redis-server" "pterodactyl" "mysql")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo -e "$service: ${GREEN}Running${NC}"
        else
            echo -e "$service: ${RED}Stopped${NC}"
        fi
    done
    
    echo "=================================="
    
    # Check disk space
    echo -e "${BLUE}Disk Usage:${NC}"
    df -h "$PANEL_DIR"
    
    # Check panel version
    if [ -f "$PANEL_DIR/config/app.php" ]; then
        echo -e "${BLUE}Panel Directory:${NC} $PANEL_DIR"
    fi
    
    # Show current URL
    if [ -f "$ENV_FILE" ]; then
        current_url=$(grep "APP_URL=" "$ENV_FILE" | cut -d'=' -f2)
        echo -e "${BLUE}Current Panel URL:${NC} $current_url"
    fi
}

# View logs
view_logs() {
    echo -e "${BLUE}📋 Recent Pterodactyl Logs${NC}"
    echo "=================================="
    echo "1. Panel Logs"
    echo "2. Laravel Logs"
    echo "3. Nginx Error Logs"
    echo "4. Management Script Logs"
    echo "5. Back to main menu"
    echo "=================================="
    
    read -p "Select log to view: " log_choice
    
    case $log_choice in
        1)
            tail -50 "$PANEL_DIR/storage/logs/laravel.log" 2>/dev/null || echo "No panel logs found"
            ;;
        2)
            tail -50 "$PANEL_DIR/storage/logs/laravel-$(date +%Y-%m-%d).log" 2>/dev/null || echo "No Laravel logs found"
            ;;
        3)
            tail -50 /var/log/nginx/error.log 2>/dev/null || echo "No Nginx error logs found"
            ;;
        4)
            tail -50 "$LOG_FILE" 2>/dev/null || echo "No management logs found"
            ;;
        5)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
}

# Maintenance mode
maintenance_mode() {
    echo -e "${BLUE}🔧 Maintenance Mode${NC}"
    echo "=================================="
    echo "1. Enable maintenance mode"
    echo "2. Disable maintenance mode"
    echo "3. Check maintenance status"
    echo "4. Back to main menu"
    echo "=================================="
    
    read -p "Select option: " maint_choice
    
    cd "$PANEL_DIR" || exit
    
    case $maint_choice in
        1)
            php artisan down
            log_message "${YELLOW}⚠️ Maintenance mode enabled${NC}"
            ;;
        2)
            php artisan up
            log_message "${GREEN}✅ Maintenance mode disabled${NC}"
            ;;
        3)
            if php artisan | grep -q "down"; then
                echo -e "${YELLOW}Maintenance mode: ENABLED${NC}"
            else
                echo -e "${GREEN}Maintenance mode: DISABLED${NC}"
            fi
            ;;
        4)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
}

# Database management
database_management() {
    echo -e "${BLUE}🗄️ Database Management${NC}"
    echo "=================================="
    echo "1. Create database backup"
    echo "2. Optimize database"
    echo "3. Run migrations"
    echo "4. Seed database"
    echo "5. Back to main menu"
    echo "=================================="
    
    read -p "Select option: " db_choice
    
    cd "$PANEL_DIR" || exit
    
    case $db_choice in
        1)
            log_message "${BLUE}Creating database backup...${NC}"
            mysqldump -u root -p pterodactyl > "$BACKUP_DIR/database_backup_$DATE.sql"
            log_message "${GREEN}✅ Database backup created${NC}"
            ;;
        2)
            log_message "${BLUE}Optimizing database...${NC}"
            php artisan optimize
            log_message "${GREEN}✅ Database optimized${NC}"
            ;;
        3)
            log_message "${BLUE}Running migrations...${NC}"
            php artisan migrate --force
            log_message "${GREEN}✅ Migrations completed${NC}"
            ;;
        4)
            log_message "${BLUE}Seeding database...${NC}"
            php artisan db:seed --force
            log_message "${GREEN}✅ Database seeded${NC}"
            ;;
        5)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
}

# Clear caches
clear_caches() {
    log_message "${BLUE}🧹 Clearing all caches...${NC}"
    cd "$PANEL_DIR" || exit
    
    php artisan cache:clear
    php artisan config:clear
    php artisan route:clear
    php artisan view:clear
    php artisan optimize:clear
    
    log_message "${GREEN}✅ All caches cleared${NC}"
}

# Update environment variable
update_env_var() {
    local var_name="$1"
    local var_value="$2"
    
    if grep -q "^${var_name}=" "$ENV_FILE"; then
        sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" "$ENV_FILE"
    else
        echo "${var_name}=${var_value}" >> "$ENV_FILE"
    fi
}

# Panel configuration management
panel_configuration() {
    while true; do
        echo -e "${PURPLE}⚙️ Panel Configuration${NC}"
        echo "=================================="
        echo "1.  Change Panel URL"
        echo "2.  Change App Name"
        echo "3.  Change Timezone"
        echo "4.  Update Database Settings"
        echo "5.  Update Mail Settings"
        echo "6.  Update Redis Settings"
        echo "7.  Change App Environment (production/local)"
        echo "8.  Enable/Disable Debug Mode"
        echo "9.  View Current Configuration"
        echo "10. Generate New App Key"
        echo "11. SSL/HTTPS Settings"
        echo "12. Back to main menu"
        echo "=================================="
        
        read -p "Select option: " config_choice
        
        case $config_choice in
            1)
                echo -e "${CYAN}Current URL:${NC}"
                grep "APP_URL=" "$ENV_FILE" 2>/dev/null || echo "Not set"
                read -p "Enter new panel URL (e.g., https://panel.yourdomain.com): " new_url
                if [[ -n "$new_url" ]]; then
                    update_env_var "APP_URL" "$new_url"
                    log_message "${GREEN}✅ Panel URL updated to: $new_url${NC}"
                    echo -e "${YELLOW}⚠️ Remember to restart services and clear cache${NC}"
                fi
                ;;
            2)
                echo -e "${CYAN}Current App Name:${NC}"
                grep "APP_NAME=" "$ENV_FILE" 2>/dev/null || echo "Not set"
                read -p "Enter new app name: " new_name
                if [[ -n "$new_name" ]]; then
                    update_env_var "APP_NAME" "\"$new_name\""
                    log_message "${GREEN}✅ App name updated to: $new_name${NC}"
                fi
                ;;
            3)
                echo -e "${CYAN}Current Timezone:${NC}"
                grep "APP_TIMEZONE=" "$ENV_FILE" 2>/dev/null || echo "Not set"
                echo "Common timezones: America/New_York, Europe/London, Asia/Tokyo, UTC"
                read -p "Enter new timezone: " new_timezone
                if [[ -n "$new_timezone" ]]; then
                    update_env_var "APP_TIMEZONE" "$new_timezone"
                    log_message "${GREEN}✅ Timezone updated to: $new_timezone${NC}"
                fi
                ;;
            4)
                echo -e "${CYAN}Database Configuration:${NC}"
                read -p "Database Host (current: $(grep "DB_HOST=" "$ENV_FILE" | cut -d'=' -f2)): " db_host
                read -p "Database Port (current: $(grep "DB_PORT=" "$ENV_FILE" | cut -d'=' -f2)): " db_port
                read -p "Database Name (current: $(grep "DB_DATABASE=" "$ENV_FILE" | cut -d'=' -f2)): " db_name
                read -p "Database Username (current: $(grep "DB_USERNAME=" "$ENV_FILE" | cut -d'=' -f2)): " db_user
                read -s -p "Database Password: " db_pass
                echo
                
                [[ -n "$db_host" ]] && update_env_var "DB_HOST" "$db_host"
                [[ -n "$db_port" ]] && update_env_var "DB_PORT" "$db_port"
                [[ -n "$db_name" ]] && update_env_var "DB_DATABASE" "$db_name"
                [[ -n "$db_user" ]] && update_env_var "DB_USERNAME" "$db_user"
                [[ -n "$db_pass" ]] && update_env_var "DB_PASSWORD" "$db_pass"
                
                log_message "${GREEN}✅ Database settings updated${NC}"
                ;;
            5)
                echo -e "${CYAN}Mail Configuration:${NC}"
                read -p "Mail Driver (smtp/sendmail/mailgun): " mail_driver
                read -p "Mail Host: " mail_host
                read -p "Mail Port: " mail_port
                read -p "Mail Username: " mail_user
                read -s -p "Mail Password: " mail_pass
                echo
                read -p "Mail Encryption (tls/ssl): " mail_encryption
                read -p "Mail From Address: " mail_from
                
                [[ -n "$mail_driver" ]] && update_env_var "MAIL_DRIVER" "$mail_driver"
                [[ -n "$mail_host" ]] && update_env_var "MAIL_HOST" "$mail_host"
                [[ -n "$mail_port" ]] && update_env_var "MAIL_PORT" "$mail_port"
                [[ -n "$mail_user" ]] && update_env_var "MAIL_USERNAME" "$mail_user"
                [[ -n "$mail_pass" ]] && update_env_var "MAIL_PASSWORD" "$mail_pass"
                [[ -n "$mail_encryption" ]] && update_env_var "MAIL_ENCRYPTION" "$mail_encryption"
                [[ -n "$mail_from" ]] && update_env_var "MAIL_FROM_ADDRESS" "$mail_from"
                
                log_message "${GREEN}✅ Mail settings updated${NC}"
                ;;
            6)
                echo -e "${CYAN}Redis Configuration:${NC}"
                read -p "Redis Host (current: $(grep "REDIS_HOST=" "$ENV_FILE" | cut -d'=' -f2)): " redis_host
                read -p "Redis Port (current: $(grep "REDIS_PORT=" "$ENV_FILE" | cut -d'=' -f2)): " redis_port
                read -p "Redis Password: " redis_pass
                
                [[ -n "$redis_host" ]] && update_env_var "REDIS_HOST" "$redis_host"
                [[ -n "$redis_port" ]] && update_env_var "REDIS_PORT" "$redis_port"
                [[ -n "$redis_host" ]] && update_env_var "REDIS_HOST" "$redis_host"
                [[ -n "$redis_port" ]] && update_env_var "REDIS_PORT" "$redis_port"
                [[ -n "$redis_pass" ]] && update_env_var "REDIS_PASSWORD" "$redis_pass"
                
                log_message "${GREEN}✅ Redis settings updated${NC}"
                ;;
            7)
                echo -e "${CYAN}Current Environment:${NC}"
                grep "APP_ENV=" "$ENV_FILE" 2>/dev/null || echo "Not set"
                echo "Options: production, local, staging"
                read -p "Enter environment (production/local/staging): " app_env
                if [[ -n "$app_env" ]]; then
                    update_env_var "APP_ENV" "$app_env"
                    log_message "${GREEN}✅ App environment updated to: $app_env${NC}"
                fi
                ;;
            8)
                echo -e "${CYAN}Current Debug Mode:${NC}"
                grep "APP_DEBUG=" "$ENV_FILE" 2>/dev/null || echo "Not set"
                read -p "Enable debug mode? (true/false): " debug_mode
                if [[ "$debug_mode" == "true" || "$debug_mode" == "false" ]]; then
                    update_env_var "APP_DEBUG" "$debug_mode"
                    log_message "${GREEN}✅ Debug mode updated to: $debug_mode${NC}"
                    if [[ "$debug_mode" == "true" ]]; then
                        echo -e "${YELLOW}⚠️ Warning: Debug mode should be disabled in production!${NC}"
                    fi
                fi
                ;;
            9)
                echo -e "${CYAN}Current Configuration:${NC}"
                echo "=================================="
                echo -e "${BLUE}App Name:${NC} $(grep "APP_NAME=" "$ENV_FILE" | cut -d'=' -f2)"
                echo -e "${BLUE}App URL:${NC} $(grep "APP_URL=" "$ENV_FILE" | cut -d'=' -f2)"
                echo -e "${BLUE}Environment:${NC} $(grep "APP_ENV=" "$ENV_FILE" | cut -d'=' -f2)"
                echo -e "${BLUE}Debug Mode:${NC} $(grep "APP_DEBUG=" "$ENV_FILE" | cut -d'=' -f2)"
                echo -e "${BLUE}Timezone:${NC} $(grep "APP_TIMEZONE=" "$ENV_FILE" | cut -d'=' -f2)"
                echo -e "${BLUE}Database Host:${NC} $(grep "DB_HOST=" "$ENV_FILE" | cut -d'=' -f2)"
                echo -e "${BLUE}Database Name:${NC} $(grep "DB_DATABASE=" "$ENV_FILE" | cut -d'=' -f2)"
                echo -e "${BLUE}Redis Host:${NC} $(grep "REDIS_HOST=" "$ENV_FILE" | cut -d'=' -f2)"
                echo -e "${BLUE}Mail Driver:${NC} $(grep "MAIL_DRIVER=" "$ENV_FILE" | cut -d'=' -f2)"
                echo "=================================="
                ;;
            10)
                echo -e "${YELLOW}⚠️ Generating new app key will invalidate all sessions!${NC}"
                read -p "Are you sure? (y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    cd "$PANEL_DIR" || exit
                    php artisan key:generate --force
                    log_message "${GREEN}✅ New app key generated${NC}"
                else
                    echo "Operation cancelled"
                fi
                ;;
            11)
                echo -e "${CYAN}SSL/HTTPS Configuration:${NC}"
                echo "1. Force HTTPS"
                echo "2. Disable HTTPS enforcement"
                echo "3. Check SSL certificate"
                echo "4. Back to configuration menu"
                read -p "Select SSL option: " ssl_choice
                
                case $ssl_choice in
                    1)
                        update_env_var "APP_URL_FORCE_HTTPS" "true"
                        log_message "${GREEN}✅ HTTPS enforcement enabled${NC}"
                        ;;
                    2)
                        update_env_var "APP_URL_FORCE_HTTPS" "false"
                        log_message "${GREEN}✅ HTTPS enforcement disabled${NC}"
                        ;;
                    3)
                        current_url=$(grep "APP_URL=" "$ENV_FILE" | cut -d'=' -f2)
                        domain=$(echo "$current_url" | sed 's|https\?://||' | sed 's|/.*||')
                        if [[ -n "$domain" ]]; then
                            echo "Checking SSL certificate for: $domain"
                            openssl s_client -connect "$domain:443" -servername "$domain" < /dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "SSL check failed"
                        else
                            echo "No domain found in APP_URL"
                        fi
                        ;;
                    4)
                        ;;
                esac
                ;;
            12)
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        if [[ "$config_choice" != "12" ]]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# User management
user_management() {
    echo -e "${PURPLE}👥 User Management${NC}"
    echo "=================================="
    echo "1. Create Admin User"
    echo "2. Reset User Password"
    echo "3. List All Users"
    echo "4. Make User Admin"
    echo "5. Remove Admin Rights"
    echo "6. Back to main menu"
    echo "=================================="
    
    read -p "Select option: " user_choice
    
    cd "$PANEL_DIR" || exit
    
    case $user_choice in
        1)
            read -p "Enter email: " user_email
            read -p "Enter first name: " first_name
            read -p "Enter last name: " last_name
            read -p "Enter username: " username
            read -s -p "Enter password: " password
            echo
            
            php artisan p:user:make --email="$user_email" --firstname="$first_name" --lastname="$last_name" --username="$username" --password="$password" --admin=1
            log_message "${GREEN}✅ Admin user created: $user_email${NC}"
            ;;
        2)
            read -p "Enter user email: " user_email
            read -s -p "Enter new password: " new_password
            echo
            
            php artisan p:user:make --email="$user_email" --password="$new_password"
            log_message "${GREEN}✅ Password reset for: $user_email${NC}"
            ;;
        3)
            echo -e "${BLUE}All Users:${NC}"
            php artisan p:user:list
            ;;
        4)
            read -p "Enter user email to make admin: " user_email
            # This would require a custom artisan command or database query
            echo -e "${YELLOW}⚠️ This feature requires manual database modification${NC}"
            echo "UPDATE users SET root_admin = 1 WHERE email = '$user_email';"
            ;;
        5)
            read -p "Enter user email to remove admin rights: " user_email
            echo -e "${YELLOW}⚠️ This feature requires manual database modification${NC}"
            echo "UPDATE users SET root_admin = 0 WHERE email = '$user_email';"
            ;;
        6)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
}

# Backup management
backup_management() {
    echo -e "${BLUE}💾 Backup Management${NC}"
    echo "=================================="
    echo "1. Create Full Backup (Files + Database)"
    echo "2. Create Files Backup Only"
    echo "3. Create Database Backup Only"
    echo "4. List Existing Backups"
    echo "5. Restore from Backup"
    echo "6. Delete Old Backups"
    echo "7. Back to main menu"
    echo "=================================="
    
    read -p "Select option: " backup_choice
    
    case $backup_choice in
        1)
            log_message "${BLUE}Creating full backup...${NC}"
            backup_panel
            mysqldump -u root -p pterodactyl > "$BACKUP_DIR/database_backup_$DATE.sql"
            log_message "${GREEN}✅ Full backup completed${NC}"
            ;;
        2)
            backup_panel
            ;;
        3)
            log_message "${BLUE}Creating database backup...${NC}"
            mkdir -p "$BACKUP_DIR"
            mysqldump -u root -p pterodactyl > "$BACKUP_DIR/database_backup_$DATE.sql"
            log_message "${GREEN}✅ Database backup created${NC}"
            ;;
        4)
            echo -e "${BLUE}Existing Backups:${NC}"
            ls -lah "$BACKUP_DIR" 2>/dev/null || echo "No backups found"
            ;;
        5)
            echo -e "${BLUE}Available Backups:${NC}"
            ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No file backups found"
            read -p "Enter backup filename to restore: " backup_file
            if [[ -f "$BACKUP_DIR/$backup_file" ]]; then
                echo -e "${YELLOW}⚠️ This will overwrite current files!${NC}"
                read -p "Are you sure? (y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    cd "$PANEL_DIR" || exit
                    tar -xzf "$BACKUP_DIR/$backup_file"
                    chown -R www-data:www-data "$PANEL_DIR"
                    log_message "${GREEN}✅ Backup restored: $backup_file${NC}"
                fi
            else
                echo -e "${RED}Backup file not found${NC}"
            fi
            ;;
        6)
            echo -e "${BLUE}Deleting backups older than 30 days...${NC}"
            find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
            find "$BACKUP_DIR" -name "*.sql" -mtime +30 -delete
            log_message "${GREEN}✅ Old backups cleaned up${NC}"
            ;;
        7)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
}

# Main menu
show_menu() {
    clear
    echo -e "${BLUE}🦕 Pterodactyl Panel Management Script${NC}"
    echo "=================================="
    echo "1.  Update Pterodactyl Panel"
    echo "2.  Create Backup"
    echo "3.  Restart Services"
    echo "4.  Check System Status"
    echo "5.  View Logs"
    echo "6.  Maintenance Mode"
    echo "7.  Database Management"
    echo "8.  Clear Caches"
    echo "9.  Panel Configuration"
    echo "10. User Management"
    echo "11. Backup Management"
    echo "12. Full Update (Backup + Update + Restart)"
    echo "13. Exit"
    echo "=================================="
}

# Main script execution
main() {
    check_root
    
    while true; do
        show_menu
        read -p "Please select an option (1-13): " choice
        
        case $choice in
            1)
                update_panel
                read -p "Press Enter to continue..."
                ;;
            2)
                backup_panel
                read -p "Press Enter to continue..."
                ;;
            3)
                restart_services
                read -p "Press Enter to continue..."
                ;;
            4)
                check_status
                read -p "Press Enter to continue..."
                ;;
            5)
                view_logs
                read -p "Press Enter to continue..."
                ;;
            6)
                maintenance_mode
                read -p "Press Enter to continue..."
                ;;
            7)
                database_management
                read -p "Press Enter to continue..."
                ;;
            8)
                clear_caches
                read -p "Press Enter to continue..."
                ;;
            9)
                panel_configuration
                ;;
            10)
                user_management
                read -p "Press Enter to continue..."
                ;;
            11)
                backup_management
                read -p "Press Enter to continue..."
                ;;
            12)
                log_message "${BLUE}🚀 Starting full update process...${NC}"
                backup_panel && update_panel && restart_services
                read -p "Press Enter to continue..."
                ;;
            13)
                log_message "${GREEN}👋 Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-13.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Run the main function
main
