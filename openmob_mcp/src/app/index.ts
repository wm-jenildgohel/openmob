#!/usr/bin/env node

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createServer } from "./create-server.js";
import { createHubClient } from "../mcp/common/hub-client.js";
import { registerAllTools } from "./register-tools.js";

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
