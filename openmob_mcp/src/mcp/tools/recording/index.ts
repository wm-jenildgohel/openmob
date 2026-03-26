import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { registerStartRecording } from "./start-recording.js";
import { registerStopRecording } from "./stop-recording.js";
import { registerGetRecording } from "./get-recording.js";
import { registerListRecordings } from "./list-recordings.js";

export function registerRecordingTools(server: McpServer, hub: HubClient): void {
  registerStartRecording(server, hub);
  registerStopRecording(server, hub);
  registerGetRecording(server, hub);
  registerListRecordings(server, hub);
}
