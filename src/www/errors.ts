export class NfcError extends Error {
  constructor(public code: NfcError.ErrorCode, message: string) {
    super(message);
  }

  public static tagLostError() {
    return new NfcError(NfcError.ErrorCode.TagLostError, 'NFC tag lost');
  }

  public static notConnectedError() {
    return new NfcError(
      NfcError.ErrorCode.NotConnectedError,
      'NFC tag is not connected'
    );
  }

  public static unknownError(errString: string): NfcError {
    throw new NfcError(NfcError.ErrorCode.Unknown, errString);
  }

  public static tagConnectionFailed() {
    throw new NfcError(
      NfcError.ErrorCode.NotConnectedError,
      `Tag connection failed`
    );
  }

  public static internalError(message: string) {
    throw new NfcError(NfcError.ErrorCode.InternalError, message);
  }
}

export namespace NfcError {
  export enum ErrorCode {
    Unknown = 'NfcUnknownError',
    InternalError = 'NfcInternalError',
    TagLostError = 'NfcTagLostError',
    NotConnectedError = 'NfcNotConnectedError',
  }
}
