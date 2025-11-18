//
//  Copyright 2018 IoTize SAS Inc.  Licensed under the MIT license.
//
//  cordova-interface.ts
//  device-com-ble.cordova BLE Cordova Plugin
//
/**
 * Partial typings for phonegap nfc cordova interface class
 */
export interface CordovaInterface {
  /**
   * Close current nfc tag
   */
  close(): Promise<void>;

  /**
   * Connect to current Tap nfc tag
   */
  connect(tech: string, timeout?: number): Promise<void>;

  /**
   * Raw NFC connect
   */
  connectRaw(tech: string, timeout?: number): Promise<void>;

  /**
   * Transeive data using Tap NFC communication protocol
   * @param data ArrayBuffer or string of hex data for transcieve
   */
  transceiveTap(data: ArrayBuffer | string): Promise<string>;

  /**
   * Transeive raw data
   * @param data ArrayBuffer or string of hex data for transcieve
   */
  transceive(data: ArrayBuffer | string): Promise<string>;

  setTapDeviceDiscoveryEnabled(value: boolean): Promise<void>;

  /**
   * Begins a reading session for the given technology.
   * @param tech String representing the technology of the tap to discover.
   */
  beginSessionFromTech(tech: string, alertMessage?: string): Promise<void>;

  endSession(): Promise<void>;

  checkTapConnection(timeout: number): Promise<CheckTapConnectionResult>;
}

export enum CheckTapConnectionResult {
  /**
   * Tag is still in range, connection is not required
   */
  IN_RANGE_READY = 0,
  /**
   * Tag in range but it has left NFC field, we need to connect again
   */
  IN_RANGE_BUT_LEFT_FIELD = 1,
  /**
   * Tag not in range anymore, a new connection is required
   */
  NOT_IN_RANGE = 2,
}
