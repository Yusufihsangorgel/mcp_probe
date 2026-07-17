/// A spec-abiding MCP server used as the happy-path fixture.
///
/// Exposes three tools (`echo`, `fail_tool`, `read_env`), one resource
/// (`probe://greeting`), and one prompt (`greet`).
library;

import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

void main() {
  WellBehavedServer(stdioChannel(input: stdin, output: stdout));
}

base class WellBehavedServer extends MCPServer
    with ToolsSupport, ResourcesSupport, PromptsSupport {
  WellBehavedServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(name: 'well_behaved', version: '1.2.3'),
        instructions: 'Fixture server for mcp_probe tests.',
      ) {
    registerTool(
      Tool(
        name: 'echo',
        description: 'Echoes back the given text.',
        inputSchema: Schema.object(
          properties: {'text': Schema.string()},
          required: ['text'],
        ),
      ),
      (request) => CallToolResult(
        content: [TextContent(text: request.arguments!['text'] as String)],
      ),
    );
    registerTool(
      Tool(
        name: 'fail_tool',
        description: 'Always reports an in-band error.',
        inputSchema: Schema.object(),
      ),
      (request) => CallToolResult(
        isError: true,
        content: [TextContent(text: 'intentional failure')],
      ),
    );
    registerTool(
      Tool(
        name: 'read_env',
        description: 'Returns the value of the MCP_PROBE_ENV variable.',
        inputSchema: Schema.object(),
      ),
      (request) => CallToolResult(
        content: [
          TextContent(text: Platform.environment['MCP_PROBE_ENV'] ?? ''),
        ],
      ),
    );
    addResource(
      Resource(
        uri: 'probe://greeting',
        name: 'greeting',
        mimeType: 'text/plain',
      ),
      (request) => ReadResourceResult(
        contents: [
          TextResourceContents(uri: request.uri, text: 'hello from fixture'),
        ],
      ),
    );
    addPrompt(
      Prompt(
        name: 'greet',
        description: 'Greets someone by name.',
        arguments: [PromptArgument(name: 'name', required: true)],
      ),
      (request) => GetPromptResult(
        messages: [
          PromptMessage(
            role: Role.user,
            content: TextContent(
              text: 'Please greet ${request.arguments?['name']}.',
            ),
          ),
        ],
      ),
    );
  }
}
