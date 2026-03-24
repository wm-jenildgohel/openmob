#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerListDevices } from "./tools/list-devices.js";
import { registerGetScreenshot } from "./tools/screenshot.js";
import { registerGetUiTree } from "./tools/ui-tree.js";
import { registerTap } from "./tools/tap.js";
import { registerTypeText } from "./tools/type-text.js";
import { registerSwipe } from "./tools/swipe.js";
import { registerLaunchApp } from "./tools/launch-app.js";
import { registerTerminateApp } from "./tools/terminate-app.js";
import { registerPressButton } from "./tools/press-button.js";
import { registerGoHome } from "./tools/go-home.js";
import { registerOpenUrl } from "./tools/open-url.js";

const server = new McpServer({
  name: "openmob",
  version: "1.0.0",
});

// Register all tools
registerListDevices(server);
registerGetScreenshot(server);
registerGetUiTree(server);
registerTap(server);
registerTypeText(server);
registerSwipe(server);
registerLaunchApp(server);
registerTerminateApp(server);
registerPressButton(server);
registerGoHome(server);
registerOpenUrl(server);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("OpenMob MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
