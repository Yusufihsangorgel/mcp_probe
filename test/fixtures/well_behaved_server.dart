/// A spec-abiding MCP server used as the happy-path fixture.
///
/// Exposes four tools (`echo`, `fail_tool`, `read_env`, `strict_args`), one
/// resource (`probe://greeting`), and one prompt (`greet`).
library;

import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:json_rpc_2/json_rpc_2.dart' show RpcException;

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
    registerTool(
      Tool(
        name: 'strict_args',
        description:
            'Rejects calls without a "text" argument at the protocol level.',
        inputSchema: Schema.object(
          properties: {'text': Schema.string()},
          required: ['text'],
        ),
      ),
      (request) {
        final text = request.arguments?['text'];
        if (text is! String) {
          // The spec allows rejecting invalid arguments with -32602 instead
          // of an in-band error.
          throw RpcException.invalidParams('missing required argument "text"');
        }
        return CallToolResult(content: [TextContent(text: text)]);
      },
      validateArguments: false,
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
