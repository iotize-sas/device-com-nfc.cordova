import { expect } from 'chai';
import { parseNdefMessage } from './parse-ndef-message';

describe('parseNdefMessage', function () {
  const tests = [
    {
      title: 'well knwon type (URI)',
      ndef: {
        tnf: 1,
        type: [85],
        id: [],
        payload: [
          0, 104, 116, 116, 112, 115, 58, 47, 47, 119, 119, 119, 46, 105, 111,
          116, 105, 122, 101, 46, 99, 111, 109,
        ],
      },
      expected: {
        tnf: 'wkt',
        value: {
          type: 'uri',
          value: 'https://www.iotize.com',
        },
      },
    },
    {
      title: 'Well known type (TEXT)',
      ndef: {
        tnf: 1,
        type: [84],
        id: [],
        payload: [
          0, 83, 101, 110, 115, 111, 114, 32, 100, 101, 109, 111, 95, 48, 48,
          48, 48, 68,
        ],
      },
      expected: {
        tnf: 'wkt',
        value: {
          type: 'text',
          value: 'Sensor demo_0000D',
        },
      },
    },
    {
      title: 'external type (Android AAR)',
      ndef: {
        tnf: 4,
        type: [
          97, 110, 100, 114, 111, 105, 100, 46, 99, 111, 109, 58, 112, 107, 103,
        ],
        id: [],
        payload: [
          99, 111, 109, 46, 105, 111, 116, 105, 122, 101, 46, 97, 110, 100, 114,
          111, 105, 100, 46, 99, 111, 109, 109, 117, 110, 105, 99, 97, 116, 105,
          111, 110, 97, 112, 112,
        ],
      },
      expected: {
        tnf: 'external',
        value: {
          domain: 'android.com:pkg',
          value: 'com.iotize.android.communicationapp',
        },
      },
    },
    {
      title: 'Unknown type',
      ndef: {
        tnf: 5,
        type: [],
        id: [],
        payload: [64, -87, -32, 68, -49, -37, -59],
      },
      expected: {
        tnf: 'unknown',
        value: {
          type: [],
          payload: [64, -87, -32, 68, -49, -37, -59],
        },
      },
    },
  ];

  tests.forEach((test) => {
    it(test.title, function () {
      expect(parseNdefMessage(test.ndef)).to.be.deep.eq(test.expected);
    });
  });
});
