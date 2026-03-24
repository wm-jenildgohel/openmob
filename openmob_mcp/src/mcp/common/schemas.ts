import { z } from "zod";

export const deviceIdSchema = z.string().describe("Device ID from list_devices");

export const coordinateSchema = {
  x: z.number().describe("X coordinate"),
  y: z.number().describe("Y coordinate"),
};

export const packageSchema = z.string().describe("Package name (Android) or bundle ID (iOS)");
