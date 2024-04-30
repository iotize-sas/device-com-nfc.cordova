import { Buffer } from 'buffer';
import { NdefRecord } from '../tap-ndef/definitions';
import { arrayEquals, toAsciiString } from '../utility';
import { TNF, WellKnownType } from './definitions';

export function parseNdefMessages(messages: NdefRecord[] | undefined | null) {
  return (messages || []).map(parseNdefMessage);
}

export function parseNdefMessage(message: NdefRecord) {
  switch (message.tnf) {
    case TNF.ABSOLUTE_URI:
      return {
        tnf: 'uri',
        value: toAsciiString(message.payload),
      };
    case TNF.WELL_KNOWN_TYPE:
      return {
        tnf: 'wkt',
        value: parseWellKnownType(message),
      };
    case TNF.EMPTY:
      return {
        tnf: 'empty',
        value: {
          type: message.type,
          payload: message.payload,
        },
      };
    case TNF.EXTERNAL:
      return {
        tnf: 'external',
        value: paseExternalType(message),
      };
    case TNF.MIME_TYPE:
      return {
        tnf: 'mimetype',
        value: parseMimeType(message),
      };
    case TNF.RFU:
      return {
        tnf: 'rfu',
        value: {
          type: message.type,
          payload: message.payload,
        },
      };
    case TNF.UNCHANGED:
      return {
        tnf: 'unchanged',
        value: {
          type: message.type,
          payload: message.payload,
        },
      };
    case TNF.UNKNOWN:
      return {
        tnf: 'unknown',
        value: {
          type: message.type,
          payload: message.payload,
        },
      };
    default:
      return {
        tnf: message.tnf,
        value: {
          type: message.type,
          payload: message.payload,
        },
      };
  }
}

function parseWellKnownType(message: Pick<NdefRecord, 'payload' | 'type'>) {
  if (arrayEquals(message.type, WellKnownType.URI)) {
    const prefixCode = message.payload[0];
    let prefix: string =
      WELL_KNOWN_TYPE_URI_PREFIX[
        prefixCode as keyof typeof WELL_KNOWN_TYPE_URI_PREFIX
      ] || '';
    return {
      type: 'uri',
      value: prefix + toAsciiString(message.payload.slice(1)),
    };
  } else if (arrayEquals(message.type, WellKnownType.TEXT)) {
    const encodingNumber = message.payload[0];
    let encoding: 'utf16le' | 'utf8' = 'utf8';
    let languageSizeInBytes = 0;
    if (typeof encodingNumber === 'number') {
      // b0: encodage utf8 s’il vaut 0 et utf16 s’il vaut 1.
      // b1: RFU (set to 0)
      // b2-b7: la taille en octets de la langue (n)
      // B8-B8+n-1: language
      // Bn: message
      const b0 = encodingNumber & 0b10000000;
      encoding = b0 ? 'utf16le' : 'utf8';
      languageSizeInBytes = encodingNumber & 0b00111111;
    }
    const text = message.payload.slice(languageSizeInBytes + 1);
    return {
      type: 'text',
      value: Buffer.from(text).toString(encoding),
    };
  }
  //   else if (arrayEquals(message.type, WellKnownType.SMPART_POSTER)) {
  //     return {
  //       type: 'sp',
  //       // TODO implement
  //       payload: message.payload,
  //     };
  //   }
  else {
    return {
      type: 'unknown',
      value: {
        type: message.type,
        payload: message.payload,
      },
    };
  }
}

function paseExternalType(message: Pick<NdefRecord, 'payload' | 'type'>) {
  const value = Buffer.from(message.payload).toString('utf8');
  const domain = Buffer.from(message.type).toString('utf8');
  return {
    domain,
    value,
  };
}

const WELL_KNOWN_TYPE_URI_PREFIX = {
  0x0: '',
  0x1: 'http://www.',
  0x2: 'http://www.',
  0x3: 'http://',
  0x4: 'https://',
  0x5: 'tel:',
  0x6: 'mailto:',
  0x07: 'ftp://anonymous:anonymous@',
  0x1d: 'file://',
  0x08: 'ftp://ftp.',
  0x09: 'ftps://',
  0x0a: 'sftp://',
  0x0b: 'smb://',
  0x0c: 'nfs://',
  0x0d: 'ftp://',
  0x0e: 'dav://',
  0x0f: 'news:',
  0x10: 'telnet://',
  0x11: 'imap:',
  0x12: 'rtsp://',
  0x13: 'urn:',
  0x14: 'pop:',
  0x15: 'sip:',
  0x16: 'sips:',
  0x17: 'tftp:',
  0x18: 'btspp://',
  0x19: 'btl2cap://',
  0x1a: 'btgoep://',
  0x1b: 'tcpobex://',
  0x1c: 'irdaobex://',
  0x1e: 'urn:epc:id:',
  0x1f: 'urn:epc:tag:',
  0x20: 'urn:epc:pat:',
  0x21: 'urn:epc:raw:',
  0x22: 'urn:epc:',
};

function parseMimeType(message: Pick<NdefRecord, 'payload'>) {
  return Buffer.from(message.payload).toString('utf8');
}
