namespace sshx.Connections;

public interface IConnectionRepository {
    Task<Connection> CreateConnectionAsync(string name, CreateConnectionRequest request,
        CancellationToken ct = default);

    Task<Connection> UpdateConnectionAsync(string name, UpdateConnectionRequest request,
        CancellationToken ct = default);

    Task<Connection> GetConnectionAsync(string name, CancellationToken ct = default);
    Task DeleteConnectionAsync(string name, CancellationToken ct = default);

    Task<IEnumerable<string>> GetNamesAsync(CancellationToken ct = default);
    Task<IEnumerable<Connection>> GetConnectionsAsync(CancellationToken ct = default);
}