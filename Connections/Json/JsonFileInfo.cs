using System.Text.Json;
using System.Text.Json.Serialization.Metadata;

namespace sshx.Connections.Json;

public sealed class JsonFileInfo(
    FileInfo file,
    int maxAttempts = JsonFileInfo.DefaultMaxAttempts,
    TimeSpan? initialDelay = null,
    double backoffMultiplier = JsonFileInfo.DefaultBackoffMultiplier)
    : IAsyncDisposable {
    private static readonly TimeSpan DefaultInitialDelay = TimeSpan.FromMilliseconds(30);
    private const int DefaultMaxAttempts = 8;
    private const double DefaultBackoffMultiplier = 1.6;

    private readonly SemaphoreSlim _gate = new(1, 1);

    public int MaxAttempts { get; } = maxAttempts;
    public TimeSpan InitialDelay { get; } = initialDelay ?? DefaultInitialDelay;
    public double BackoffMultiplier { get; } = backoffMultiplier;

    public async Task WriteAsync<T>(T value, JsonTypeInfo<T> typeInfo, CancellationToken ct = default) {
        await _gate.WaitAsync(ct);
        try {
            await ExecuteWithRetry(async () => {
                await using var stream = OpenWritableStream();
                await JsonSerializer.SerializeAsync(stream, value, typeInfo, ct);
            }, ct);
        }
        finally {
            _gate.Release();
        }
    }

    public async Task<T> ReadAsync<T>(JsonTypeInfo<T> typeInfo, CancellationToken ct = default) {
        await _gate.WaitAsync(ct);
        try {
            return await ExecuteWithRetry(async () => {
                await using var stream = OpenReadableStream();
                var value = await JsonSerializer.DeserializeAsync(stream, typeInfo, ct);
                if (value == null) {
                    throw new NullReferenceException("Deserialized value is null");
                }

                return value;
            }, ct);
        }
        finally {
            _gate.Release();
        }
    }

    private async Task<T> ExecuteWithRetry<T>(Func<Task<T>> action, CancellationToken ct) {
        var attempts = 0;
        var delay = InitialDelay;

        while (true) {
            ct.ThrowIfCancellationRequested();
            try {
                return await action();
            }
            catch (IOException) when (++attempts < MaxAttempts) {
                await Task.Delay(delay, ct);
                delay = TimeSpan.FromMilliseconds(delay.TotalMilliseconds * BackoffMultiplier);
            }
        }
    }

    private async Task ExecuteWithRetry(Func<Task> action, CancellationToken ct) {
        await ExecuteWithRetry<object>(async () => {
            await action();
            return null!;
        }, ct);
    }

    private FileStream OpenReadableStream() {
        return file.Open(FileMode.Open, FileAccess.Read, FileShare.Read);
    }

    private FileStream OpenWritableStream() {
        return file.Open(FileMode.Create, FileAccess.Write, FileShare.None);
    }

    public ValueTask DisposeAsync() {
        return ValueTask.CompletedTask;
    }
}