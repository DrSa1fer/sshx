# sshx

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/language-bash-blue.svg)](https://www.gnu.org/software/bash/)

**sshx** is a lightweight and intuitive command-line manager for your SSH connections. It helps you organize, quickly access, and manage multiple servers without needing to remember IP addresses, ports, or usernames. All your connection data is stored locally in simple JSON files, putting you in full control.

## ✨ Features

*   **Simple Connection Management:** Easily create, list, update, and delete SSH connections with straightforward commands.
*   **Quick Connect:** Launch an SSH session instantly using a connection name: `sshx connect my-server`.
*   **Local & Transparent Storage:** All connection data (host, user, port, etc.) is stored in JSON files within your user's application data directory (e.g., `~/.config/sshx/` on Linux/macOS). No external databases or cloud services required.
*   **User-Friendly Interface:** Designed with a clear and concise command structure, making it accessible for both beginners and experienced users.
*   **Portable & Lightweight:** Written in Bash, it has minimal dependencies and runs anywhere Bash is available.

## 📦 Installation

### Prerequisites
*   **Bash** (version 4.0 or higher)
*   **ssh-client** (the standard `ssh` command must be available in your system's PATH)

### Install via Git
The recommended way to install `sshx` is to clone the repository and add it to your PATH.

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/DrSa1fer/sshx.git
    cd sshx
    ```

2.  **Make the script executable and move it to a directory in your PATH (optional but recommended):**
    ```bash
    chmod +x sshx
    # Example: move to /usr/local/bin for system-wide access
    sudo mv sshx /usr/local/bin/
    ```

### Quick Install (using cURL)
You can also download the script directly using `curl` or `wget`.

```
# Using curl
curl -L https://raw.githubusercontent.com/DrSa1fer/sshx/main/sshx -o sshx
chmod +x sshx
sudo mv sshx /usr/local/bin/ # Optional
```

## 🚀 Usage

`sshx` uses a simple `command` `subcommand` `[options]` pattern.

### Core Commands

#### 1.  **Add a Connection**
    ```
    sshx add <name> <user>@<host>[:port]
    # example:
    sshx add web-server deploy@192.168.1.100
    sshx add db-master admin@db.internal.company.com:5432
    ```

#### 2.  **List Connections**
    ```
    sshx list
    # This will display a formatted table of all your saved connections.
    ```

#### 3.  **Connect to a Server**
    ```bash
    sshx connect <name>
    # example:
    sshx connect web-server
    ```
    This command is an alias for the standard `ssh` command, passing all the saved parameters.

#### 4.  **Show Connection Details**
    ```bash
    sshx show <name>
    ```
    Displays the stored JSON data for a specific connection.

#### 5.  **Update a Connection**
    ```bash
    sshx update <name> [--user <user>] [--host <host>] [--port <port>]
    ```
    # example:
    # Change the user for 'web-server'
    sshx update web-server --user newadmin
    ```

#### 6.  **Delete a Connection**
    ```
    sshx delete <name>
    ```

#### 7.  **Get Help**
    ```
    sshx --help
    sshx <command> --help
    ```

## ⚙️ Configuration

`sshx` stores its data in a platform-appropriate application directory:

*   **Linux:** `~/.config/sshx/`
*   **macOS:** `~/Library/Application Support/sshx/`
*   **Other:** A `.sshx` directory in the user's home (`~/`).

Within this directory, you will find JSON files, one for each connection you create (e.g., `web-server.json`).

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! This project aims to be a simple, robust tool, so please open an issue to discuss any major changes before submitting a pull request.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details (if one exists in the repository).
