namespace sshx.Connections;

public sealed record CreateConnectionRequest(
    string Description,
    string User,
    string Host,
    int Port
);