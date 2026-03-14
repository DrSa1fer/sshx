# sshx

**sshx** is a lightweight command-line SSH connection manager designed to make it easy to create, store, update, and launch SSH connections.
All connection data is stored locally as JSON files, without relying on external services.


## ✨ Features

* Create and manage named SSH connections
* Store multiple servers with user, host, and port settings
* Update or delete existing connections
* Launch SSH sessions using a simple command:

  ```bash
  sshx connect <name>
  ```
* JSON-based local storage under the user’s AppData directory
* Minimalistic and fast CLI built with `.NET`


## 📦 Installation

### Build from source

```bash
git clone https://github.com/DrSa1fer/sshx.git
cd sshx
dotnet build -c Release
```

The built binary will be located in:

```
./bin/Release/<framework>/sshx
```

## 📁 Data Storage Location

sshx stores all connections in:

```
%AppData%/sshx/connections/
```

Each connection is stored as an individual JSON file.


## 🧠 Connection Structure

A stored connection looks like this:

```json
{
  "Name": "my-server",
  "User": "root",
  "Host": "192.168.1.10",
  "Port": 22
}
```


## 🛠 Commands

### Connect to a server

```bash
sshx connect <name>
```

### Create a connection

```bash
sshx create <name> <user> <host> [--port PORT]
```

### Update an existing connection

```bash
sshx update <name> [--user USER] [--host HOST] [--port PORT]
```

### Delete a connection

```bash
sshx delete <name>
```

### Show connection details

```bash
sshx show <name>
```

### List all stored connections

```bash
sshx list
```

## 🧱 Project Structure

```
sshx/
├── Connections/
│   ├── Connection.cs
│   ├── CreateConnectionRequest.cs
│   ├── UpdateConnectionRequest.cs
│   ├── IConnectionRepository.cs
│   └── Json/
│       ├── JsonConnectionRepository.cs
│       ├── JsonConnectionRepositoryOptions.cs
│       ├── ConnectionFileInfo.cs
│       ├── JsonFileInfo.cs
│       └── SourceGenerationJsonSerializerContext.cs
├── Program.cs
├── sshx.csproj
└── README.md
```

## 📜 License

This project is licensed under the **GNU General Public License (GPL)**.
See the `LICENSE` file for details.
