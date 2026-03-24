export interface Device {
  id: string;
  serial: string;
  model: string;
  manufacturer: string;
  osVersion: string;
  sdkVersion: number;
  screenWidth: number;
  screenHeight: number;
  batteryLevel: number;
  batteryStatus: string;
  connectionType: string;
  status: string;
  bridgeActive: boolean;
  platform: string;
  deviceType: string;
}

export interface UiNode {
  index: number;
  text: string;
  className: string;
  resourceId: string;
  contentDesc: string;
  bounds: {
    left: number;
    top: number;
    right: number;
    bottom: number;
    centerX: number;
    centerY: number;
  };
  visible: boolean;
}

export interface ActionResult {
  success: boolean;
  error?: string;
  data?: Record<string, unknown>;
}

export interface ScreenshotResult {
  screenshot: string;
  width: number;
  height: number;
}

export interface UiTreeResult {
  nodes: UiNode[];
}
