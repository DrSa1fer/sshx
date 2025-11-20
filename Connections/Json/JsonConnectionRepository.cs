namespace sshx.Connections.Json;

public class JsonConnectionRepository : IConnectionRepository {
    private readonly DirectoryInfo _directory;

    public JsonConnectionRepository(JsonConnectionRepositoryOptions options) {
        _directory = new DirectoryInfo(options.ConnectionsPath);
        if (!_directory.Exists) {
            _directory.Create();
        }
    }

    public async Task<Connection> CreateConnectionAsync(string name, CreateConnectionRequest request,
        CancellationToken ct = default) {
        EnsureNotExists(name);
        var file = File(name);
        await using var connectionInfo = new ConnectionFileInfo(file);

        var connection = new Connection(
            name,
            request.Description,
            request.User,
            request.Host,
            request.Port
        );

        await connectionInfo.WriteAsync(connection, ct);
        return connection;
    }

    public async Task<Connection> UpdateConnectionAsync(string name, UpdateConnectionRequest request,
        CancellationToken ct = default) {
        EnsureExists(name);
        var original = File(name);
        await using var connectionInfo = new ConnectionFileInfo(original);
        var old = await connectionInfo.ReadAsync(ct);

        var updated = new Connection(
            request.NewName ?? old.Name,
            request.NewDescription ?? old.Description,
            request.NewUser ?? old.User,
            request.NewHost ?? old.Host,
            request.NewPort ?? old.Port
        );

        if (request.NewName != null && request.NewName != name) {
            EnsureNotExists(request.NewName);
            var renamed = File(request.NewName);
            await using var newConnectionInfo = new ConnectionFileInfo(renamed);
            await newConnectionInfo.WriteAsync(updated, ct);
            original.Delete();
        }
        else {
            await connectionInfo.WriteAsync(updated, ct);
        }

        return updated;
    }

    public Task DeleteConnectionAsync(string name, CancellationToken ct = default) {
        EnsureExists(name);
        File(name).Delete();
        return Task.CompletedTask;
    }

    public async Task<Connection> GetConnectionAsync(string name, CancellationToken ct = default) {
        EnsureExists(name);
        await using var connectionInfo = new ConnectionFileInfo(File(name));
        return await connectionInfo.ReadAsync(ct);
    }

    public Task<IEnumerable<string>> GetNamesAsync(CancellationToken ct = default) {
        return Task.FromResult(_directory.GetFiles("*.json").Select(f => Path.GetFileNameWithoutExtension(f.Name)));
    }

    public async Task<IEnumerable<Connection>> GetConnectionsAsync(CancellationToken ct = default) {
        return await Task.WhenAll(
            _directory.GetFiles("*.json").Select(async f => {
                await using var connectionInfo = new ConnectionFileInfo(f);
                return await connectionInfo.ReadAsync(ct);
            })
        );
    }

    private FileInfo File(string name) {
        return new FileInfo(Path.Combine(_directory.FullName, $"{name}.json"));
    }

    private void EnsureExists(string name) {
        if (!File(name).Exists) {
            throw new ArgumentException($"Connection {name} does not exist");
        }
    }

    private void EnsureNotExists(string name) {
        if (File(name).Exists) {
            throw new ArgumentException($"Connection {name} already exists");
        }
    }
}