# Dotfiles

Helper scripts to get my daily drivers up and running quickly on my systems. Heavy vibecoding involved.

## Disclaimer

> This script installs software, modifies your shell, and touches your system configuration. If you blindly `curl | bash` strangers' code from the internet, you get what you deserve. Review `setup.sh` first.

## Quick Install

On your fresh Debian-based install just run:

```bash
curl -fsSL https://raw.githubusercontent.com/pascscha/dotfiles/refs/heads/master/setup.sh | bash
```

## Features

- **nala**: Modern apt frontend with faster mirror selection
- **zsh**: Zsh with Oh My Zsh and hostname-colored prompt theme
- **micro**: Modern terminal text editor
- **docker**: Container runtime with docker-compose
- **vscodium**: VS Code without Microsoft telemetry
- **tailscale**: Mesh VPN with auto-login
- **ssh-client**: Generate ed25519 SSH key
- **ssh-server**: Secure SSH server (key-only, no root login)

## Test with Docker

During development you can use the Dockerfile to test:

```bash
docker build -t dotfiles . && docker run --rm -it -v "$(pwd)/setup.sh:/setup.sh:ro" dotfiles bash -c "cat /setup.sh | bash; exec bash"
```

This mimics the `curl | bash` workflow. If zsh is installed, the script will automatically switch to it. Otherwise you'll drop into bash.

## License

[MIT-ish](LICENSE): use at your own risk, I'm not responsible for anything.
