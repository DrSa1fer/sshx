using System.Text.Json.Serialization;

namespace sshx.Connections.Json;

[JsonSerializable(typeof(int))]
[JsonSerializable(typeof(bool))]
[JsonSerializable(typeof(string))]
[JsonSerializable(typeof(Connection))]
public partial class SourceGenerationJsonSerializerContext : JsonSerializerContext;