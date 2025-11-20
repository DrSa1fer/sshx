namespace sshx.Connections.Json;

public sealed class ConnectionFileInfo(FileInfo file) : IAsyncDisposable {
    private readonly JsonFileInfo _fileInfo = new(file);

    public async Task WriteAsync(Connection value, CancellationToken ct = default) {
        try {
            await _fileInfo.WriteAsync<Connection>(value, SourceGenerationJsonSerializerContext.Default.Connection, ct);
        }
        catch (Exception e) {
            throw new Exception("Failed to write connection", e);
        }
    }

    public async Task<Connection> ReadAsync(CancellationToken ct = default) {
        try {
            return await _fileInfo.ReadAsync<Connection>(SourceGenerationJsonSerializerContext.Default.Connection, ct);
        }
        catch (Exception e) {
            throw new Exception("Failed to read connection", e);
        }
    }

    public async ValueTask DisposeAsync() {
        await _fileInfo.DisposeAsync();
    }
}