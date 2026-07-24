/// @docImport 'harness.dart';
library;

/// An error that occurred while starting an MCP server and performing the
/// initialize handshake with it.
///
/// Thrown by [McpServerHarness.start]. The harness kills the server process
/// before throwing, so a failed start never leaks a child process.
final class McpHandshakeException implements Exception {
  /// Creates a handshake exception.
  McpHandshakeException(
    this.message, {
    this.pid,
    this.rawInitializeResult,
    this.serverStderr,
  });

  /// A description of what went wrong.
  final String message;

  /// The pid of the server process, if it was started.
  ///
  /// The process has already been killed by the time this exception is
  /// thrown; the pid is only useful for diagnostics.
  final int? pid;

  /// The raw `initialize` result as it appeared on the wire, if the server
  /// responded at all.
  ///
  /// This is `null` when the server never answered the `initialize` request.
  final Map<String, Object?>? rawInitializeResult;

  /// Anything the server wrote to stderr before the handshake failed.
  final String? serverStderr;

  @override
  String toString() {
    final buffer = StringBuffer('McpHandshakeException: $message');
    if (serverStderr != null && serverStderr!.isNotEmpty) {
      buffer.write('\nserver stderr:\n$serverStderr');
    }
    return buffer.toString();
  }
}
