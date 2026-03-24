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

export interface UiTreeResult {
  nodes: UiNode[];
}
