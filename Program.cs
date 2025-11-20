using System.CommandLine;
using System.Diagnostics;
using sshx.Connections;
using sshx.Connections.Json;
using Console = System.Console;

var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
var connectionsOptions = new JsonConnectionRepositoryOptions($"{appData}/sshx/connections/");

var nameArgument = new Argument<string>("name") {
    Description = "The connection name."
};

var userArgument = new Argument<string>("user") {
    Description = "The SSH username used for authentication."
};

var hostArgument = new Argument<string>("host") {
    Description = "The SSH host or IP address."
};


var nameOption = new Option<string>("name", "-n", "--name") {
    Description = "New name for the connection (used for updates)."
};
var userOption = new Option<string>("user", "-u", "--user") {
    Description = "The SSH username."
};
var hostOption = new Option<string>("host", "-a", "--host") {
    Description = "The SSH host or IP address."
};
var portOption = new Option<int>("port", "-p", "--port") {
    Description = "The SSH port. Default is 22."
};
var descriptionOption = new Option<string>("description", "-d", "--description") {
    Description = "The description."
};


var createCommand = new Command("create", "Create a new SSH connection.") {
    nameArgument, userArgument, hostArgument, portOption, descriptionOption
};

var updateCommand = new Command("update", "Update an existing SSH connection.") {
    nameArgument, nameOption, userOption, hostOption, portOption, descriptionOption
};

var deleteCommand = new Command("delete", "Delete an SSH connection.") {
    nameArgument
};

var connectCommand = new Command("connect", "Start an SSH session using the stored connection.") {
    nameArgument
};

var showCommand = new Command("show", "Display details of a stored SSH connection.") {
    nameArgument
};

var listCommand = new Command("list", "List all stored SSH connections.");

var aliasCommand = new Command("alias", "Add sshx alias to your shell RC file.");

connectCommand.SetAction(async result => {
    var name = result.GetRequiredValue(nameArgument) ?? throw new Exception("Connection name is required.");
    var repo = new JsonConnectionRepository(connectionsOptions);
    var connection = await repo.GetConnectionAsync(name);

    var ssh = new Process {
        StartInfo = {
            UseShellExecute = false,
            FileName = "/usr/bin/ssh",
            Arguments = $"{connection.User}@{connection.Host} -p {connection.Port}"
        }
    };

    ssh.Start();
    ssh.WaitForExit();
});

createCommand.SetAction(async result => {
    var repo = new JsonConnectionRepository(connectionsOptions);

    await repo.CreateConnectionAsync(
        result.GetValue(nameArgument) ?? throw new Exception("Connection name is required."),
        new CreateConnectionRequest(
            result.GetResult(descriptionOption)?.GetValue(descriptionOption) ?? string.Empty,
            result.GetRequiredValue(userArgument),
            result.GetRequiredValue(hostArgument),
            result.GetResult(portOption)?.GetValue(portOption) ?? 22
        )
    );
});

updateCommand.SetAction(async result => {
    var repo = new JsonConnectionRepository(connectionsOptions);

    await repo.UpdateConnectionAsync(
        result.GetValue(nameArgument) ?? throw new Exception("Connection name is required."),
        new UpdateConnectionRequest(
            result.GetResult(nameOption)?.GetValue(nameOption),
            result.GetResult(descriptionOption)?.GetValue(descriptionOption),
            result.GetResult(userOption)?.GetValue(userOption),
            result.GetResult(hostOption)?.GetValue(hostOption),
            result.GetResult(portOption)?.GetValue(portOption)
        )
    );
});

deleteCommand.SetAction(async result => {
    var repo = new JsonConnectionRepository(connectionsOptions);
    await repo.DeleteConnectionAsync(result.GetValue(nameArgument) ??
                                     throw new Exception("Connection name is required."));
});

showCommand.SetAction(async result => {
    var repo = new JsonConnectionRepository(connectionsOptions);
    var connection =
        await repo.GetConnectionAsync(result.GetValue(nameArgument) ??
                                      throw new Exception("Connection name is required."));
    Console.WriteLine(connection);
});

listCommand.SetAction(async _ => {
    var repo = new JsonConnectionRepository(connectionsOptions);
    var connections = await repo.GetConnectionsAsync();

    foreach (var (connection, index) in connections.Select((c, i) => (c, i))) {
        Console.WriteLine($"[{index}] {connection.Name} | {connection.User}@{connection.Host}:{connection.Port}");
    }
});


aliasCommand.SetAction(async _ => {
    var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    var bashRc = Path.Combine(home, ".bashrc");
    var zshRc = Path.Combine(home, ".zshrc");

    var shellRcPaths = new List<string>();
    
    if (File.Exists(zshRc)) {
        shellRcPaths.Add(zshRc);
    }
    
    if (File.Exists(bashRc)) {
        shellRcPaths.Add(bashRc);
    }

    if (shellRcPaths.Count < 1) {
        Console.WriteLine("Could not determine shell RC file.");
        return;
    }
    
    foreach (var shellRcPath in shellRcPaths) {
        var aliasLine = $"alias sshx='{Path.GetFullPath(Environment.ProcessPath ?? throw new Exception("process path is null"))}'";
      
        await File.AppendAllTextAsync(shellRcPath, $"{aliasLine}{Environment.NewLine}");
        Console.WriteLine($"Alias added to {shellRcPath}. Reload your shell or run 'source {shellRcPath}' to apply.");
    }
});

var rootCommand = new RootCommand(
    "sshx is a modern SSH connection manager that lets you organize, create, and connect to servers effortlessly") {
    connectCommand,
    createCommand,
    updateCommand,
    deleteCommand,
    showCommand,
    listCommand,
    aliasCommand,
};

return await rootCommand.Parse(args).InvokeAsync();