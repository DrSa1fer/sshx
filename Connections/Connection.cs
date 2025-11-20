namespace sshx.Connections;

public class Connection(string name, string? description, string user, string host, int port) {
    public string Name { get; } = name;
    public string? Description { get; } = description;
    public string User { get; } = user;
    public string Host { get; } = host;
    public int Port { get; } = port;

    public override string ToString() {
        return
            $"""
             {Name} - {User}@{Host}:{Port}
             {Description}
             """;
    }
}