import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";

export function registerStartRecording(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "start_recording",
    {
      description:
        "Start recording the device screen — captures video (and optionally audio) for bug reports and test evidence. " +
        "Recording continues until you call stop_recording. Uses scrcpy if available (unlimited duration, audio support), " +
        "otherwise falls back to Android's built-in recorder (3 min max, no audio).",
      inputSchema: {
        device_id: deviceIdSchema,
        format: z.enum(["mkv", "mp4"]).optional().describe("Video format — mkv recommended (survives crashes). Default: mkv"),
        max_duration_seconds: z.number().optional().describe("Auto-stop after this many seconds. Default: 180"),
        include_audio: z.boolean().optional().describe("Record device audio too (requires scrcpy). Default: false"),
        video_bitrate: z.string().optional().describe("Video quality — '4M' for normal, '8M' for high. Default: 4M"),
      },
    },
    async ({ device_id, format, max_duration_seconds, include_audio, video_bitrate }) => {
      try {
        const result = await hub.post<{ data: { id: string; backend: string; format: string } }>(
          "/recordings/start",
          {
            device_id,
            format: format ?? "mkv",
            max_duration_seconds: max_duration_seconds ?? 180,
            include_audio: include_audio ?? false,
            video_bitrate: video_bitrate ?? "4M",
          }
        );

        const backend = result.data?.backend ?? "unknown";
        const fmt = result.data?.format ?? format ?? "mkv";
        return createTextResponse(
          result,
          `Started screen recording (${backend}, ${fmt} format). Call stop_recording when done.`
        );
      } catch (error) {
        return createErrorResponse(
          error,
          "Could not start recording — make sure the device is connected and no other recording is active"
        );
      }
    }
  );
}
