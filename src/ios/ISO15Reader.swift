//
//  IOS15Reader.swift
//  NFC
//
//  Created by dev@iotize.com on 23/07/2019.
//  Copyright © 2019 dev@iotize.com. All rights reserved.
//

import UIKit
import CoreNFC


public extension String {
    
     func dataFromHexString() -> Data {
        var bytes = [UInt8]()
        for i in 0..<(count/2) {
            let range = index(self.startIndex, offsetBy: 2*i)..<index(self.startIndex, offsetBy: 2*i+2)
            let stringBytes = self[range]
            let byte = strtol((stringBytes as NSString).utf8String, nil, 16)
            bytes.append(UInt8(byte))
        }
        return Data(bytes: UnsafePointer<UInt8>(bytes), count:bytes.count)
    }
    
}

extension Data {
    
    func hexEncodedString() -> String {
        let format = "%02hhX"
        return map { String(format: format, $0) }.joined()
    }
}

@available(iOS 13.0, *)
class ST25DVReader : NSObject {
   
    typealias Completion = (Error?) -> ()
    
    private var comSession: NFCTagReaderSession?
    private var tag: NFCISO15693Tag?

    static var   MB_CTRL_DYN : UInt8 = 0x0D
    
    private var connectionCompleted :  Completion?
    
    /*ST25 commands*/
    static var   ISO15693_CUSTOM_ST25DV_CMD_WRITE_MB_MSG : UInt8 =  0xAA;
    static var   ISO15693_CUSTOM_ST25DV_CMD_READ_MB_MSG_LENGTH : Int =  0xAB;
    static var   ISO15693_CUSTOM_ST25DV_CMD_READ_MB_MSG = 0xAC;
    
    static var   ISO15693_CUSTOM_ST_CMD_READ_DYN_CONFIG : Int =  0xAD;
    static var   ISO15693_CUSTOM_ST_CMD_WRITE_DYN_CONFIG : Int = 0xAE;

    static var   DELAY : UInt32 = 1000;   // timeout resolution in millionths of second
    static var   NB_MAX_RETRY : Int = 50;
    
    override init() {
        super.init()
    }

    func initSession( alertMessage: String, completed: @escaping (Error?)->() ) {
        
        guard NFCNDEFReaderSession.readingAvailable else {
            completed( NFCReaderError( NFCReaderError.readerErrorUnsupportedFeature ))
            return
        }
        
        connectionCompleted = completed
        
        if NFCNDEFReaderSession.readingAvailable {
            comSession = NFCTagReaderSession(pollingOption: [.iso15693], delegate: self, queue: nil)
            comSession?.alertMessage = alertMessage
            comSession?.begin()
        }
    }

    func invalidateSession( message :String) {
        comSession?.alertMessage = message
        comSession?.invalidate()
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
extension ST25DVReader : NFCTagReaderSessionDelegate {
    // MARK: - NFCTagReaderSessionDelegate
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // If necessary, you may perform additional operations on session start.
        // At this point RF polling is enabled.
        print( "tagReaderSessionDidBecomeActive" )
    }
 
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
       // If necessary, you may handle the error. Note session is no longer valid.
        // You must create a new session to restart RF polling.
        print( "tagReaderSession:didInvalidateWithError - \(error)" )
        connectionCompleted?(error)
        self.comSession = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
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
            self.tag = iso15tag
        default:
            let error = NFCReaderError( NFCReaderError.ndefReaderSessionErrorTagNotWritable )
           invalidateSession( message: error.localizedDescription  )
           connectionCompleted?(error)
           return;
        }
     
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
            strongSelf.connectionCompleted?(nil)
        }
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
        guard let tag = self.tag else {
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
        
        guard let tag = self.tag else {
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
        guard let tag = self.tag else {
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
    func transceiveRaw(request: Data, completed: @escaping (Data?, Error?) -> ()) {
        guard (request.count < 2) else {
            completed(nil, NFCReaderError(NFCReaderError.readerErrorInvalidParameterLength))
            return
        }
        var flags = Int(request[0])
        var commandCode = Int(request[1])
        var dataToSend = request.dropFirst(2)
        self.tag?.sendRequest(requestFlags: flags, commandCode: commandCode, data: dataToSend, resultHandler: {(result: Result<(NFCISO15693ResponseFlag, Data?), any Error>) in
            switch result {
            case .success((let flag, let data)):
                let firstByteBuffer = withUnsafeBytes(of: flag.rawValue) { Data($0)}
                var resultData = Data(firstByteBuffer)
                if let nonNilData = data {
                    resultData.append(nonNilData)
                }
                completed(resultData, nil)
                return
            case .failure(let error):
                completed(nil, error)
                return
            }
        })
    }
}
    
