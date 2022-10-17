import {
  bufferToHexString,
  hexStringToBuffer,
} from '@iotize/common/byte-converter';
import {
  ComProtocolConnectOptions,
  ComProtocolDisconnectOptions,
  ComProtocolOptions,
  ComProtocolSendOptions,
  ConnectionState,
} from '@iotize/tap/protocol/api';
import { QueueComProtocol } from '@iotize/tap/protocol/core';
import { from, Observable } from 'rxjs';

import { CordovaInterface } from './cordova-interface';
import { NfcError } from './errors';
import { debug } from './logger';

declare var nfc: CordovaInterface;

export class NFCComProtocol extends QueueComProtocol {
  constructor(
    options: ComProtocolOptions = {
      connect: {
        timeout: 2000,
      },
      disconnect: {
        timeout: 1000,
      },
      send: {
        timeout: 1000,
      },
    }
  ) {
    super();
    this.options = options;
    if (typeof nfc == undefined) {
      console.warn(
        'NFC plugin has not been setup properly. Global variable NFC does not exist'
      );
    }
  }

  public static iOSProtocol(): NFCComProtocol {
    return new NFCComProtocol({
      connect: {
        timeout: 10000, // bigger timer on connect as connect launches a reading session
      },
      disconnect: {
        timeout: 1000,
      },
      send: {
        timeout: 1000,
      },
    });
  }

  _connect(options?: ComProtocolConnectOptions): Observable<any> {
    debug('_connect', options);
    const connectPromise = nfc.connect(
      'android.nfc.tech.NfcV',
      this.options.connect.timeout
    );
    return from(connectPromise);
  }

  _disconnect(options?: ComProtocolDisconnectOptions): Observable<any> {
    return from(nfc.close());
  }

  write(data: Uint8Array): Promise<any> {
    throw new Error('Method not implemented.');
  }

  read(): Promise<Uint8Array> {
    throw new Error('Method not implemented.');
  }

  send(
    data: Uint8Array,
    options?: ComProtocolSendOptions
  ): Observable<Uint8Array> {
    const promise = nfc
      .transceive(bufferToHexString(data))
      .then((response: string) => {
        if (typeof response != 'string') {
          throw NfcError.internalError(
            `Internal error. Plugin should respond a hexadecimal string`
          );
        }
        debug('NFC plugin response: ', response);
        return hexStringToBuffer(response);
      })
      .catch((errString) => {
        if (typeof errString === 'string') {
          const error = stringToError(errString);
          if (
            error.code === NfcError.ErrorCode.NotConnectedError ||
            error.code === NfcError.ErrorCode.TagLostError
          ) {
            this._onConnectionLost(error);
          }
          throw error;
        } else {
          throw errString;
        }
      });
    return from(promise);
  }

  _onConnectionLost(error: NfcError) {
    if (this.connectionState !== ConnectionState.DISCONNECTED) {
      this.setConnectionState(ConnectionState.DISCONNECTED);
    }
  }
}

/**
 * Convert error string returned by the plugin into an error object
 * It only checks a few Android error string for now
 *
 * TODO complete implementation with other error types
 *
 * @param errString
 */
function stringToError(errString: string): NfcError {
  const errStringLc = errString.toLowerCase();
  if (errStringLc.indexOf('tag was lost') >= 0) {
    return NfcError.tagLostError();
  } else if (errStringLc.indexOf('not connected') >= 0) {
    return NfcError.notConnectedError();
  } else {
    return NfcError.unknownError(errString);
  }
}
