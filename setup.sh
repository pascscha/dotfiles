#!/bin/bash

BOLD='\033[1m'
DIM='\033[2m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
WHITE='\033[37m'
RESET='\033[0m'

info()    { echo -e "${BLUE}  ○${RESET} $1"; }
success() { echo -e "${GREEN}  ●${RESET} $1"; }
warn()    { echo -e "${YELLOW}  ⚠${RESET} $1"; }
error()   { echo -e "${RED}  ✗${RESET} $1"; }

if [ "$(id -u)" -eq 0 ]; then
    error "This script should not be run as root. It will use sudo when needed."
    exit 1
fi

HOSTNAME_COLOR=""
SAVED_STTY=""

save_stty() {
    SAVED_STTY=$(stty -g 2>/dev/null) || SAVED_STTY=""
}

restore_stty() {
    [ -n "$SAVED_STTY" ] && stty "$SAVED_STTY" 2>/dev/null
}

cleanup() {
    restore_stty
    printf '\033[?25h'
    tput cnorm 2>/dev/null
}
trap cleanup EXIT

hash_hostname_to_color() {
    local colors=("red" "green" "yellow" "magenta" "cyan" "white")
    local hash=0
    local hostname="$1"
    for ((i=0; i<${#hostname}; i++)); do
        hash=$((hash + $(printf '%d' "'${hostname:$i:1}")))
    done
    echo "${colors[$((hash % ${#colors[@]}))]}"
}

generate_jispwoso_theme() {
    local theme_file="$1"
    local hostname_color="$2"
    cat > "$theme_file" << EOF
local ret_status="%(?:%{\$fg_bold[green]%}➜ :%{\$fg_bold[red]%}➜ %s)"
PROMPT=$'%{\$fg[${hostname_color}]%}%n@%m: %{\$reset_color%}%{\$fg[blue]%}%~ %{\$reset_color%}%{\$fg_bold[blue]%}\$(git_prompt_info)%{\$fg_bold[blue]%} % %{\$reset_color%}
\${ret_status} %{\$reset_color%} '

PROMPT2="%{\$fg_bold[black]%}%_> %{\$reset_color%}"
RPROMPT=""

ZSH_THEME_GIT_PROMPT_PREFIX="git:(%{\$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{\$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{\$fg[blue]%}) %{\$fg[yellow]%}✗%{\$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{\$fg[blue]%})"
EOF
}

install_nala() {
    info "Installing nala..."
    sudo apt-get update
    sudo apt-get install -y nala
    info "Fetching fastest mirrors with nala..."
    sudo nala fetch --auto -y || warn "Nala fetch failed (non-fatal)"
    
    info "Creating apt -> nala aliases..."
    cat > "$HOME/.apt_aliases" << 'EOF'
alias apt='nala'
alias apt-get='nala'
alias apt-cache='nala'
alias sudo='sudo '
EOF
    
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && ! grep -qxF 'source ~/.apt_aliases' "$rc" && echo -e "\nsource ~/.apt_aliases" >> "$rc"
    done
    success "Nala installed with apt aliases"
}

install_zsh() {
    info "Installing zsh with Oh My Zsh..."
    
    if command -v nala &> /dev/null; then
        sudo nala install -y zsh curl git
    else
        sudo apt-get update
        sudo apt-get install -y zsh curl git
    fi
    
    if ! command -v zsh &> /dev/null; then
        error "Zsh not found after install."
        return 1
    fi
    
    local current_shell
    current_shell=$(getent passwd "$USER" | cut -d: -f7)
    if [[ "$current_shell" != *"zsh"* ]]; then
        info "Changing default shell to Zsh..."
        sudo usermod --shell "$(which zsh)" "$USER"
    fi
    
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    info "Configuring .zshrc..."
    local zshrc_file="$HOME/.zshrc"
    local hostname_color="${HOSTNAME_COLOR:-$(hash_hostname_to_color "$(hostname)")}"
    
    sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="jispwoso"/' "$zshrc_file"
    
    local custom_theme_dir="$HOME/.oh-my-zsh/custom/themes"
    mkdir -p "$custom_theme_dir"
    generate_jispwoso_theme "$custom_theme_dir/jispwoso.zsh-theme" "$hostname_color"
    
    cat > "$HOME/.zsh_aliases" << 'EOF'
export PATH="/usr/games:$PATH"

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias sl='sl -e'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
EOF
    
    # well spotted, you actually did read the code before install
    if command -v nala &> /dev/null; then
        sudo nala install -y sl 2>/dev/null
    else
        sudo apt-get install -y sl 2>/dev/null
    fi
    
    grep -qxF 'source ~/.zsh_aliases' "$zshrc_file" || echo -e "\nsource ~/.zsh_aliases" >> "$zshrc_file"
    grep -q 'export PATH=$HOME/.local/bin:$PATH' "$zshrc_file" || echo 'export PATH=$HOME/.local/bin:$PATH' >> "$zshrc_file"
    
    info "Configuring history search..."
    cat > "$HOME/.inputrc" << 'EOF'
"\e[A": history-search-backward
"\e[B": history-search-forward
EOF
    
    grep -q 'bindkey "\^"\[A" history-beginning-search-backward' "$zshrc_file" || cat >> "$zshrc_file" << 'EOF'

bindkey "^[[A" history-beginning-search-backward
bindkey "^[[B" history-beginning-search-forward
EOF
    
    success "Zsh installed with jispwoso theme (hostname color: $hostname_color)"
}

install_micro() {
    info "Installing micro editor..."
    if command -v nala &> /dev/null; then
        sudo nala install -y micro
    else
        sudo apt-get update
        sudo apt-get install -y micro
    fi
    success "Micro installed successfully"
}

install_docker() {
    info "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        success "Docker is already installed"
        return 0
    fi
    
    info "Installing dependencies..."
    if command -v nala &> /dev/null; then
        sudo nala install -y ca-certificates curl gnupg
    else
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
    fi
    
    info "Adding Docker GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    info "Adding Docker repository..."
    local arch
    arch=$(dpkg --print-architecture)
    local distro
    distro=$(. /etc/os-release && echo "$ID")
    local codename
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    
    if [ "$distro" = "ubuntu" ] || [[ "$(. /etc/os-release && echo "$ID_LIKE")" == *"ubuntu"* ]]; then
        echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $codename stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    info "Installing Docker packages..."
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    info "Adding user to docker group..."
    sudo usermod -aG docker "$USER"
    
    success "Docker installed successfully"
    warn "Log out and back in for docker group to take effect"
}

install_vscodium() {
    info "Installing VSCodium..."
    
    if command -v codium &> /dev/null; then
        success "VSCodium is already installed"
        return 0
    fi
    
    info "Installing dependencies..."
    if command -v nala &> /dev/null; then
        sudo nala install -y wget gpg
    else
        sudo apt-get update
        sudo apt-get install -y wget gpg
    fi
    
    info "Adding VSCodium GPG key..."
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | \
        sudo gpg --dearmor -o /usr/share/keyrings/vscodium-archive-keyring.gpg
    
    info "Adding VSCodium repository..."
    echo -e 'Types: deb\nURIs: https://download.vscodium.com/debs\nSuites: vscodium\nComponents: main\nArchitectures: amd64 arm64\nSigned-by: /usr/share/keyrings/vscodium-archive-keyring.gpg' | \
        sudo tee /etc/apt/sources.list.d/vscodium.sources > /dev/null
    
    info "Installing VSCodium package..."
    sudo apt-get update
    sudo apt-get install -y codium
    
    success "VSCodium installed successfully"
}

install_tailscale() {
    info "Installing Tailscale..."
    
    if command -v tailscale &> /dev/null; then
        success "Tailscale is already installed"
    else
        curl -fsSL https://tailscale.com/install.sh | sudo sh
        success "Tailscale installed"
    fi
    
    info "Starting Tailscale login..."
    sudo tailscale up
}

install_ssh_client() {
    if ! command -v ssh-keygen &> /dev/null; then
        info "Installing openssh-client..."
        if command -v nala &> /dev/null; then
            sudo nala install -y openssh-client
        else
            sudo apt-get update
            sudo apt-get install -y openssh-client
        fi
    fi
    
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        info "Generating ed25519 SSH key..."
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "$USER@$(hostname)"
        success "SSH key generated: $HOME/.ssh/id_ed25519"
    else
        success "SSH key already exists: $HOME/.ssh/id_ed25519"
    fi
}

install_ssh_server() {
    info "Installing and configuring SSH server..."
    
    if command -v nala &> /dev/null; then
        sudo nala install -y openssh-server
    else
        sudo apt-get update
        sudo apt-get install -y openssh-server
    fi
    
    local sshd_config="/etc/ssh/sshd_config"
    
    info "Hardening SSH configuration..."
    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$sshd_config"
    sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$sshd_config"
    
    restore_stty
    printf '\033[?25h'
    
    echo
    echo -e "${YELLOW}  Paste your public key to add to authorized_keys:${RESET}"
    echo -e "${DIM}  (press Enter when done, empty to skip)${RESET}"
    if [ -t 0 ]; then
        read -r pubkey
    else
        read -r pubkey < /dev/tty
    fi
    
    if [ -n "$pubkey" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        if [ -f "$HOME/.ssh/authorized_keys" ] && grep -qF "$pubkey" "$HOME/.ssh/authorized_keys"; then
            warn "Key already exists in authorized_keys, skipping"
        elif echo "$pubkey" | ssh-keygen -l -f - 2>/dev/null; then
            echo "$pubkey" >> "$HOME/.ssh/authorized_keys"
            chmod 600 "$HOME/.ssh/authorized_keys"
            success "Public key added to authorized_keys"
        else
            error "Invalid SSH public key, skipping"
        fi
    fi
    
    if [ ! -f "$HOME/.ssh/authorized_keys" ] || [ ! -s "$HOME/.ssh/authorized_keys" ]; then
        warn "No authorized_keys configured. Password auth will remain enabled."
        warn "Add your key to ~/.ssh/authorized_keys and run: sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart ssh"
    else
        sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$sshd_config"
        success "SSH server configured (root login disabled, key-only auth)"
    fi
    
    info "Restarting SSH service..."
    sudo systemctl enable ssh
    sudo systemctl restart ssh
    
    save_stty
    printf '\033[?25l'
}

print_header() {
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║${RESET}   ${BOLD}${WHITE}Dotfiles Installer${RESET}                                      ${BOLD}${CYAN}║${RESET}"
    echo -e "${BOLD}${CYAN}║${RESET}   ${DIM}https://github.com/pascscha/dotfiles${RESET}                    ${BOLD}${CYAN}║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
}

select_color() {
    local colors=("red" "green" "yellow" "magenta" "cyan" "white" "")
    local color_names=("Red" "Green" "Yellow" "Magenta" "Cyan" "White" "Auto-detect")
    local color_codes=(31 32 33 35 36 37 0)
    local selected=6
    
    while true; do
        clear
        print_header
        echo -e "${BOLD}  Select hostname color:${RESET}"
        echo
        for i in "${!colors[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                if [ "${colors[$i]}" ]; then
                    echo -e "  ${CYAN}❯${RESET}  \033[${color_codes[$i]}m${color_names[$i]}${RESET}"
                else
                    echo -e "  ${CYAN}❯${RESET}  ${DIM}${color_names[$i]}${RESET}"
                fi
            else
                if [ "${colors[$i]}" ]; then
                    echo -e "    \033[${color_codes[$i]}m${color_names[$i]}${RESET}"
                else
                    echo -e "    ${DIM}${color_names[$i]}${RESET}"
                fi
            fi
        done
        echo
        echo -e "${DIM}  ↑/↓ Navigate  ·  Enter Select  ·  Esc Cancel${RESET}"
        
        if [ -t 0 ]; then
            IFS= read -rsn1 key
        else
            IFS= read -rsn1 key < /dev/tty
        fi
        case "$key" in
            "")
                HOSTNAME_COLOR="${colors[$selected]}"
                return 0
                ;;
            $'\e')
                if [ -t 0 ]; then
                    IFS= read -rsn2 -t 0.1 seq
                else
                    IFS= read -rsn2 -t 0.1 seq < /dev/tty
                fi
                case "$seq" in
                    '[A') [ "$selected" -gt 0 ] && ((selected--)) ;;
                    '[B') [ "$selected" -lt 6 ] && ((selected++)) ;;
                esac
                ;;
            q) return 0 ;;
        esac
    done
}

interactive_menu() {
    local features=("nala" "zsh" "micro" "docker" "vscodium" "tailscale" "ssh-client" "ssh-server")
    local descriptions=("Modern apt frontend" "Zsh + Oh My Zsh" "Terminal editor" "Container runtime" "VS Code without telemetry" "Mesh VPN" "Generate SSH key" "Secure SSH server")
    local selected=(true true true true false false true false)
    local cursor=0
    local hostname_color
    
    save_stty
    printf '\033[?25l'
    
    while true; do
        hostname_color="${HOSTNAME_COLOR:-$(hash_hostname_to_color "$(hostname)")}"
        
        clear
        print_header
        
        echo -e "${BOLD}  Select features to install:${RESET}"
        echo
        for i in "${!features[@]}"; do
            local checkbox="○"
            [ "${selected[$i]}" = true ] && checkbox="●"
            local prefix="  "
            [ "$i" -eq "$cursor" ] && prefix="${CYAN}❯${RESET} "
            
            if [ "$i" -eq "$cursor" ]; then
                echo -e "${prefix}${BOLD}[${checkbox}] ${features[$i]}${RESET}  ${DIM}${descriptions[$i]}${RESET}"
            else
                echo -e "${prefix} [${checkbox}] ${features[$i]}  ${DIM}${descriptions[$i]}${RESET}"
            fi
        done
        
        echo
        echo -e "  ${DIM}────────────────────────────────────────${RESET}"
        echo -e "  Hostname color: ${BOLD}${hostname_color}${RESET}  ${DIM}(c to change)${RESET}"
        echo
        echo -e "${DIM}  ↑/↓ Navigate  ·  Space Select  ·  c Color  ·  Enter Install  ·  q Quit${RESET}"
        
        if [ -t 0 ]; then
            IFS= read -rsn1 key
        else
            IFS= read -rsn1 key < /dev/tty
        fi
        case "$key" in
            ' ')
                if [ "${selected[$cursor]}" = true ]; then
                    selected[$cursor]=false
                else
                    selected[$cursor]=true
                fi
                ;;
            c|C)
                restore_stty
                printf '\033[?25h'
                select_color
                save_stty
                printf '\033[?25l'
                ;;
            "")
                INSTALL_NALA="${selected[0]}"
                INSTALL_ZSH="${selected[1]}"
                INSTALL_MICRO="${selected[2]}"
                INSTALL_DOCKER="${selected[3]}"
                INSTALL_VSCODIUM="${selected[4]}"
                INSTALL_TAILSCALE="${selected[5]}"
                INSTALL_SSH_CLIENT="${selected[6]}"
                INSTALL_SSH_SERVER="${selected[7]}"
                break
                ;;
            $'\e')
                if [ -t 0 ]; then
                    IFS= read -rsn2 -t 0.1 seq
                else
                    IFS= read -rsn2 -t 0.1 seq < /dev/tty
                fi
                case "$seq" in
                    '[A') [ "$cursor" -gt 0 ] && ((cursor--)) ;;
                    '[B') [ "$cursor" -lt $((${#features[@]} - 1)) ] && ((cursor++)) ;;
                esac
                ;;
            q|Q)
                echo
                info "Installation cancelled"
                exit 0
                ;;
        esac
    done
}

run_installation() {
    echo
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  Installing selected features...${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    
    [ "$INSTALL_NALA" = true ] && { echo -e "${BOLD}${WHITE}  ▸ Installing nala...${RESET}"; install_nala; echo; }
    [ "$INSTALL_ZSH" = true ] && { echo -e "${BOLD}${WHITE}  ▸ Installing zsh...${RESET}"; install_zsh; echo; }
    [ "$INSTALL_MICRO" = true ] && { echo -e "${BOLD}${WHITE}  ▸ Installing micro...${RESET}"; install_micro; echo; }
    [ "$INSTALL_DOCKER" = true ] && { echo -e "${BOLD}${WHITE}  ▸ Installing docker...${RESET}"; install_docker; echo; }
    [ "$INSTALL_VSCODIUM" = true ] && { echo -e "${BOLD}${WHITE}  ▸ Installing vscodium...${RESET}"; install_vscodium; echo; }
    [ "$INSTALL_TAILSCALE" = true ] && { echo -e "${BOLD}${WHITE}  ▸ Installing tailscale...${RESET}"; install_tailscale; echo; }
    [ "$INSTALL_SSH_CLIENT" = true ] && { echo -e "${BOLD}${WHITE}  ▸ Installing ssh-client...${RESET}"; install_ssh_client; echo; }
    [ "$INSTALL_SSH_SERVER" = true ] && { echo -e "${BOLD}${WHITE}  ▸ Installing ssh-server...${RESET}"; install_ssh_server; echo; }
    
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${GREEN}  Installation complete!${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
}

interactive_menu
run_installation

if [ "$INSTALL_ZSH" = true ] && [ -t 0 ]; then
    exec zsh
fi
