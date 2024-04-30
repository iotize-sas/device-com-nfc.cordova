export interface TapNfcTagPayload {
  type?: number;
  name?: string;
  aar?: string;
  uri?: string;
  macAddress?: string;
  ssid?: string;
}

export interface NdefEvent {
  tag: NdefTag;
}
export interface NdefRecord {
  id: any[];
  payload: number[];
  tnf: number;
  type: number[];
}
export interface NdefTag {
  canMakeReadOnly: boolean;
  id: number[];
  isWritable: boolean;
  maxSize: number;
  ndefMessage: NdefRecord[];
  techTypes: string[];
}
