export enum TNF {
  EMPTY = 0x00, // Empty
  WELL_KNOWN_TYPE = 0x01, // NFC Forum well-known type [NFC RTD]
  MIME_TYPE = 0x02, // Media-type [RFC 2046]
  ABSOLUTE_URI = 0x03, // Absolute URI [RFC 3986]
  EXTERNAL = 0x04, // NFC Forum external type [NFC RTD]
  UNKNOWN = 0x05,
  UNCHANGED = 0x06, //
  RFU = 0x07, // Reserved for future use
}

export const WellKnownType = {
  URI: [0x55],
  TEXT: [0x54],
  SMPART_POSTER: [0x53, 0x70],
};
