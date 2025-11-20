namespace sshx.Connections;

public sealed record UpdateConnectionRequest(
    string? NewName,
    string? NewDescription,
    string? NewUser,
    string? NewHost,
    int? NewPort
);