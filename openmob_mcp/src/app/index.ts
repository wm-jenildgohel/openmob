#!/usr/bin/env node

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createServer } from "./create-server.js";
import { createHubClient } from "../mcp/common/hub-client.js";
import { registerAllTools } from "./register-tools.js";

const server = createServer();
const hub = createHubClient();

registerAllTools(server, hub);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("OpenMob MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
