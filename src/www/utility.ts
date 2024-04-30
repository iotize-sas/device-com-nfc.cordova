import { bufferToAsciiString } from '@iotize/common/byte-converter';

export function toAsciiString(payload: number[]): string {
  if (payload.length > 0 && payload[0] === 0) {
    payload = payload.slice(1);
  }
  return bufferToAsciiString(payload as any as Uint8Array);
}

export function arrayEquals(a1: number[], a2: number[]) {
  return (
    a1.length === a2.length && a1.every((a1Item, index) => a1Item === a2[index])
  );
}
