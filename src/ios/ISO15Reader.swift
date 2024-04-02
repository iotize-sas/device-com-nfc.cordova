//
//  IOS15Reader.swift
//  NFC
//
//  Created by dev@iotize.com on 23/07/2019.
//  Copyright © 2019 dev@iotize.com. All rights reserved.
//

import UIKit
import CoreNFC

@available(iOS 13.0, *)
class ST25DVReader : NFCTagReader {
    
    var iso15Tag: NFCISO15693Tag?
    var detectionRetryCount = 0
    
    override func invalidateSession( message :String) {
        super.invalidateSession(message: message)
        iso15Tag = nil
    }
    
    override func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {

        print( "tagReaderSession:didDectectTag" )
        guard let session = self.comSession else {
            return;
        }
        if tags.count > 1 {
            // Restart polling in 500 milliseconds.
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 Tap is detected. Please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        guard let tag = tags.first else {
            return;
        }
        
        switch tag {
        case .iso15693(let iso15tag):
            self.iso15Tag = iso15tag
            detectionRetryCount = 0
            
            // Connect to tag
            
            session.connect(to: tag) { [weak self] (error: Error?) in
                guard let strongSelf = self  else {
                    return;
                }
                
                if error != nil {
                    let error = NFCReaderError( NFCReaderError.readerTransceiveErrorTagNotConnected )
                    strongSelf.invalidateSession( message: error.localizedDescription  )
                    strongSelf.connectionCompleted?(error)
                    return
                }
                print( "connected to tag" )
                strongSelf.tag = tag
                strongSelf.connectionCompleted?(nil)
                iso15tag.readNDEF(completionHandler: {(ndef: NFCNDEFMessage?, error: Error?) in
                    if let readNdef = ndef {
                        strongSelf.onDiscoverCompletion?(iso15tag.toJSON(ndefMessage: readNdef), nil)
                    } else {
                        strongSelf.onDiscoverCompletion?(iso15tag.toJSON(ndefMessage: nil), nil)
                    }
                })
            }
            return
        default:
            detectionRetryCount += 1
            if (detectionRetryCount < 5) {
                usleep(ST25DVReader.DELAY)
                session.restartPolling()
                return
            }
            let error = NFCReaderError( NFCReaderError.ndefReaderSessionErrorTagNotWritable )
           invalidateSession( message: error.localizedDescription  )
           connectionCompleted?(error)
           return
        }
    }
    
    func send( request: String, completed: @escaping (Data?,Error?)->() ) {
        
        guard NFCNDEFReaderSession.readingAvailable else {
            let error = NFCReaderError( NFCReaderError.readerErrorUnsupportedFeature )
            invalidateSession( message: error.localizedDescription )
            completed( nil, error )
            return
        }
        
        guard comSession != nil && comSession!.isReady else {
            let error = NFCReaderError( NFCReaderError.readerTransceiveErrorTagNotConnected )
            invalidateSession( message: error.localizedDescription )
            completed( nil, error )
            return
        }
        
        let requestData : Data = request.dataFromHexString()
        print( "Transceive - \(requestData.hexEncodedString())" )
        transceiveTap(request: requestData,
                   completed: { ( response: Data?, error: Error?) in
                            if nil != error {
                                self.invalidateSession( message: error?.localizedDescription ?? "Error" )
                                completed( nil, error )
                                return
                            }
                            else {
                                completed( response, nil)
                                return
                            }
                    })
    }
    
   
}

@available(iOS 13.0, *)
extension ST25DVReader {
    
    

    func transceiveTap(request: Data, completed: @escaping (Data?, Error?)->()){
       

        checkMBEnabled( completed: { ( error: Error?) in
                if nil != error {
                    self.invalidateSession( message: error?.localizedDescription ?? "Error" )
                    completed( nil, error )
                    return
                }
                print( "Com enabled" )
                self.sendRequest( request: request,
                    nbTry: ST25DVReader.NB_MAX_RETRY,
                    completed: { ( response: Data?, error: Error?) in
                        if nil != error {
                            self.invalidateSession( message: error?.localizedDescription ?? "Error" )
                            completed( nil, error )
                            return
                        }
                        completed(response, nil)
                    })
            })
    
    }

    func sendRequest(request: Data, nbTry: Int, completed: @escaping (Data?, Error?)->() ) {
        guard let tag = self.iso15Tag else {
            let error = NFCReaderError( NFCReaderError.readerTransceiveErrorTagNotConnected )
            invalidateSession( message: error.localizedDescription  )
            completed(nil, error )
            return;
        }

        if (nbTry <= 0){
            let error = NFCReaderError( NFCReaderError.readerTransceiveErrorRetryExceeded )
            invalidateSession( message: error.localizedDescription  )
            completed(nil, error )
            return
        }
        
        var parameters  = Data( bytes:[request.count - 1], count: 1 )
        parameters.append(request)
        print( "Send - \(parameters.hexEncodedString())" )

        tag.customCommand(requestFlags: [.highDataRate],
                          customCommandCode: 0xAA,
            customRequestParameters:  parameters,
            completionHandler: { (response: Data?, error: Error?) in
                if nil != error {
                    usleep(ST25DVReader.DELAY)
                    self.sendRequest( request: request, nbTry: nbTry - 1, completed: completed )
                    return
                }
                    usleep(ST25DVReader.DELAY * 10) // free ST25DV for SPI
                    self.readResponse( nbTry: nbTry , completed: completed)
            })
        
    }
    
    func readResponse( nbTry: Int, completed: @escaping (Data?, Error?)->() ) {
        
        guard let tag = self.iso15Tag else {
            let error = NFCReaderError( NFCReaderError.readerTransceiveErrorTagNotConnected )
            invalidateSession( message: error.localizedDescription  )
            completed( nil, error )
            return;
        }
        
        //We have tried enough timeout and return
        if (nbTry <= 0){
            print( "Read Abandonned" )
            let error = NFCReaderError( NFCReaderError.readerTransceiveErrorRetryExceeded )
            invalidateSession( message: error.localizedDescription  )
            completed( nil, error )
            return;
        }
        
        print( "Read \(nbTry)" )
  
        //check Mailbox
        tag.customCommand(requestFlags: [.highDataRate],
                          customCommandCode: 0xAD,
                          customRequestParameters:  Data(bytes: [UInt8(0x0D)], count: 1),
                          completionHandler: { (response: Data, error: Error?) in
                            if nil != error {
                                usleep(ST25DVReader.DELAY)
                                self.readResponse( nbTry: nbTry - 1, completed: completed )
                                return
                            }
                            
                            print( "Read resonse" )
                            
                            if ( (response.count >= 1) && ( (response[0]&0x1) != 0 ) && ( (response[0]&0x2) != 0  )){

                                print( "Read Value - \(Data(response).hexEncodedString())" )
                                tag.customCommand(requestFlags: [.highDataRate],
                                                  customCommandCode: 0xAC,
                                                  customRequestParameters:  Data(bytes: [UInt8(0), UInt8(0)], count: 2),
                                                  completionHandler: { (response: Data, error: Error?) in
                                                    if nil != error {
                                                        self.invalidateSession( message: error?.localizedDescription ?? "Error" )
                                                        completed( nil, error )
                                                        return
                                                    }
                                                    print( "got Value - \(Data(response).hexEncodedString())" )
                                                    completed(response,nil)
                                                    return
                                })
                               
                            }
                            else {
                                usleep(ST25DVReader.DELAY)
                                self.readResponse( nbTry: nbTry - 1, completed: completed )
                            }
                        
            })
        
        
    }
    
    func checkMBEnabled(completed: @escaping (Error?)->()) {
        guard let tag = self.iso15Tag else {
            let error = NFCReaderError( NFCReaderError.readerTransceiveErrorTagNotConnected )
             invalidateSession( message: error.localizedDescription  )
             completed( error )
            return;
        }
        
        //Read Config
        tag.customCommand(requestFlags: [.highDataRate],
            customCommandCode: 0xAD,
            customRequestParameters:  Data(bytes: [UInt8(0x0D)], count: 1),
            completionHandler: { (response: Data, error: Error?) in
                if nil != error {
                    self.invalidateSession( message: error?.localizedDescription ?? "Error"  )
                    completed(error)
                    return
                }
            
                if ( response.count == 0) {
                    let error = NFCReaderError( NFCReaderError.readerTransceiveErrorTagResponseError )
                    self.invalidateSession( message: error.localizedDescription  )
                    completed( error )
                    return
                }

                
                let current = response[0];
                
                //We should reset mailbox
                if ( (current != 0x41) && (current != 0x81) ) {
            
                    //disable
                    tag.customCommand(requestFlags: [.highDataRate],
                        customCommandCode: 0xAE,
                        customRequestParameters:  Data(bytes: [UInt8(0x0D), UInt8(0x00)], count: 2),
                        completionHandler: { (response: Data, error: Error?) in
                            if nil != error {
                                self.invalidateSession( message: error?.localizedDescription ?? "Error" )
                                completed( error )
                                return
                            }
                            
                            //enable
                            tag.customCommand(requestFlags: [.highDataRate],
                                customCommandCode: 0xAE,
                                customRequestParameters:  Data(bytes: [UInt8(0x0D), UInt8(0x01)], count: 2),
                                completionHandler: { (response: Data, error: Error?) in
                                    if nil != error {
                                        self.invalidateSession( message: error?.localizedDescription ?? "Error" )
                                        completed( error )
                                        return
                                    }
                                  
                                    completed(nil)
                                    return

                                })
                        })
                }
                    //We are ok to go
                else
                {
                    completed(nil)
                    return
                }
                
            })
    }
    
    //full transparent mode
    
    @available(iOS 14.0, *)
    func transceiveRaw(request: Data, completed: @escaping (Data?, Error?) -> (), nbTry: Int = NB_MAX_RETRY) {
        guard (request.count >= 2) else {
            completed(nil, NFCReaderError(NFCReaderError.readerErrorInvalidParameterLength))
            return
        }
        let flags = Int(request[0])
        let commandCode = Int(request[1])
        let dataToSend = request.dropFirst(2)
        
        print("TRANSCEIVE RAW SEND \(request.hexEncodedString())")
        
        guard let tag = self.iso15Tag else {
            completed(nil, NFCReaderError(NFCReaderError.readerTransceiveErrorTagConnectionLost))
            return
        }
        
        print("TRANSCEIVE RAW SEND ON ISO15TAG TRY \(nbTry), SESSION READY \(String(describing: comSession?.isReady))")
        
        tag.sendRequest(requestFlags: flags, commandCode: commandCode, data: dataToSend, resultHandler: {(result: Result<(NFCISO15693ResponseFlag, Data?), any Error>) in

            print("SEND_REQUEST_CALLBACK")
            switch result {
            case .success((let flag, let data)):
                let firstByteBuffer = withUnsafeBytes(of: flag.rawValue) { Data($0)}
                var resultData = Data(firstByteBuffer)
                if let nonNilData = data {
                    resultData.append(nonNilData)
                }
                print("TRANSCEIVE RAW RETURN \(resultData.hexEncodedString())")
                completed(resultData, nil)
                return
            case .failure(let error):
                print("TRANSCEIVE RAW ERROR \(error.localizedDescription), TRY \(nbTry)")
                if (nbTry >= 0) {
                    usleep(ST25DVReader.DELAY)
                    return self.transceiveRaw(request: request, completed: completed, nbTry: nbTry - 1)
                }
                completed(nil, error)
                return
            }
        })
    }
}
