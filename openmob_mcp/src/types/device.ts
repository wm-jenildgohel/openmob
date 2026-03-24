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
