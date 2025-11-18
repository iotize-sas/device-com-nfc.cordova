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
import { catchError, defer, Observable, of, switchMap, throwError } from 'rxjs';

import {
  CheckTapConnectionResult,
  CordovaInterface,
} from './cordova-interface';
import { NfcError } from './errors';
import { debug } from './logger';

declare var nfc: CordovaInterface;

class PromiseQueue {
  queue = Promise.resolve<any>(true);

  add<T>(operation: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      this.queue = this.queue.then(operation).then(resolve).catch(reject);
    });
  }
}

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

  private _sendQueue = new PromiseQueue();

  /**
   * We force tag connection with nfc as we need to refresh tag
   * @param options
   * @returns
   */
  connect(options?: ComProtocolConnectOptions): Observable<void> {
    if (this.connectionState === ConnectionState.CONNECTED) {
      return defer(async () => {
        try {
          return await nfc.checkTapConnection(this.options.connect.timeout);
        } catch (err) {
          this.setConnectionState(ConnectionState.DISCONNECTED);
          throw err;
        }
      }).pipe(
        switchMap((connectionCheckState) => {
          switch (connectionCheckState) {
            case CheckTapConnectionResult.IN_RANGE_READY:
              return of(undefined);
            case CheckTapConnectionResult.IN_RANGE_BUT_LEFT_FIELD:
              this.setConnectionState(ConnectionState.CONNECTING);
              return super.connect(options);
            case CheckTapConnectionResult.NOT_IN_RANGE:
            default:
              this.setConnectionState(ConnectionState.DISCONNECTED);
              return throwError(() => NfcError.tagLostError());
          }
        })
      );
    }
    return super.connect(options);
  }

  /**
   * Not used as we have rewrote "connect()" function
   * @param options
   * @returns
   */
  _connect(options?: ComProtocolConnectOptions): Observable<any> {
    return defer(async () => {
      debug('_connect', options);
      try {
        await nfc.connect(
          'android.nfc.tech.NfcV',
          this.options.connect.timeout
        );
      } catch (err) {
        if (typeof err === 'string') {
          if (err === 'Tag connection failed') {
            throw NfcError.tagConnectionFailed();
          } else {
            throw NfcError.unknownError(err);
          }
        }
        throw err;
      }
    });
  }

  _disconnect(options?: ComProtocolDisconnectOptions): Observable<any> {
    return defer(async () => {
      await nfc.close();
      this._sendQueue = new PromiseQueue();
    });
  }

  /**
   * Not used
   * @param options
   * @returns
   */
  async write(data: Uint8Array): Promise<any> {
    throw new Error('Method not implemented.');
  }

  /**
   * Not used
   * @param options
   * @returns
   */
  async read(): Promise<Uint8Array> {
    throw new Error('Method not implemented.');
  }

  send(
    data: Uint8Array,
    options?: ComProtocolSendOptions
  ): Observable<Uint8Array> {
    return defer(async () => {
      return await this._sendQueue.add(async () => {
        try {
          const response = await nfc.transceiveTap(bufferToHexString(data));
          if (typeof response != 'string') {
            throw NfcError.internalError(
              `Internal error. Plugin should respond a hexadecimal string`
            );
          }
          debug('NFC plugin response: ', response);
          return hexStringToBuffer(response);
        } catch (errString) {
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
        }
      });
    });
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
