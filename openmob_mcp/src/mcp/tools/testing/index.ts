import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { registerRunTest } from "./run-test.js";

export function registerTestingTools(server: McpServer, hub: HubClient): void {
  registerRunTest(server, hub);
}
