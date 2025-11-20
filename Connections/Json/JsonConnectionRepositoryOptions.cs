namespace sshx.Connections.Json;

public class JsonConnectionRepositoryOptions(string connectionsPath) {
    public string ConnectionsPath { get; } = connectionsPath;
}