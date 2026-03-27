#!/usr/bin/env node

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createServer } from "./create-server.js";
import { createHubClient } from "../mcp/common/hub-client.js";
import { registerAllTools } from "./register-tools.js";

const HELP_TEXT = `openmob-mcp — OpenMob MCP Server for mobile device automation

Usage:
  openmob-mcp              Start the MCP server on stdio
  openmob-mcp --help       Show this help message
  openmob-mcp --version    Show version

Environment variables:
  OPENMOB_HUB_URL    Full Hub API URL (e.g. http://127.0.0.1:8686/api/v1)
  OPENMOB_HUB_PORT   Hub port number (default: auto-detect 8686-8690)

The server communicates via stdio using the Model Context Protocol (MCP).
It connects to a running OpenMob Hub to control mobile devices.
`;

function printHelp(): void {
  process.stdout.write(HELP_TEXT);
}

function printVersion(): void {
  process.stdout.write("openmob-mcp 0.0.10\n");
}

// Handle --help / -h / --version before starting the server
const args = process.argv.slice(2);
if (args.includes("--help") || args.includes("-h")) {
  printHelp();
  process.exit(0);
}
if (args.includes("--version") || args.includes("-v")) {
  printVersion();
  process.exit(0);
}

async function main() {
  const hub = await createHubClient();
  console.error(`[openmob-mcp] Hub URL: ${hub.hubUrl}`);

  const server = createServer();
  registerAllTools(server, hub);

  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("[openmob-mcp] MCP Server running on stdio");
}

main().catch((error) => {
  console.error("[openmob-mcp] Fatal error:", error);
  process.exit(1);
});
