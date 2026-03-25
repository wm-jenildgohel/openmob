import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../mcp/common/hub-client.js";
import { registerDeviceTools } from "../mcp/tools/device/index.js";
import { registerActionTools } from "../mcp/tools/action/index.js";
import { registerTestingTools } from "../mcp/tools/testing/index.js";

export function registerAllTools(server: McpServer, hub: HubClient): void {
  registerDeviceTools(server, hub);
  registerActionTools(server, hub);
  registerTestingTools(server, hub);
}
