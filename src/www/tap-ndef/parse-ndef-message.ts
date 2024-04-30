import { toAsciiString } from '../utility';
import { NdefRecord, TapNfcTagPayload } from './definitions';

/**
 * We manage only on NDEF message with 3 records:
 * record 0 = URI; record 1 = AAR; record 2 = BLE MAC ADDRESS / BSSID; record 3: universal link
 */
export function parseTapNdefMessage(messages: NdefRecord[]): TapNfcTagPayload {
  let result: TapNfcTagPayload = {};
  if (messages.length >= 1) {
    let asciiUri = messages[0].payload;
    result.uri = toAsciiString(asciiUri);
  }
  if (messages.length >= 2) {
    result.aar = toAsciiString(messages[1].payload);
  }
  if (messages.length >= 3) {
    let payload3 = messages[2].payload;
    let type = payload3[0];
    let content = payload3.slice(1);
    result.type = type;

    switch (type) {
      case TapNdefProtocolType.BLE:
        result.macAddress = convertBytesToBLEAddress(content);
        break;
      case TapNdefProtocolType.WiFi:
        result.ssid = toAsciiString(content);
        break;
    }
  }
  if (messages.length >= 4) {
    result.name = toAsciiString(messages[3].payload);
  }
  return result;
}

enum TapNdefProtocolType {
  WiFi = 0x20,
  BLE = 0x40,
}

function convertBytesToBLEAddress(bytes: number[]): string {
  return bytes
    .map((byte) => {
      if (byte < 0) {
        byte += 256;
      }
      let byteString = '0' + byte.toString(16).toUpperCase();
      byteString = byteString.slice(-2);
      return byteString;
    })
    .reverse()
    .join(':');
}
