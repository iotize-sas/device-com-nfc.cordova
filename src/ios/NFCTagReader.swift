import CoreNFC

@available(iOS 13.0, *)
class NFCTagReader : NSObject, NFCTagReaderSessionDelegate  {
    
    private var plugin: NfcPlugin

    typealias Completion = (Error?) -> ()
    typealias CompletionWithJSONResponse = ([AnyHashable: Any]?, Error?) -> ()
        
    internal var comSession: NFCTagReaderSession?
    internal var tag: NFCTag?

    static var   MB_CTRL_DYN : UInt8 = 0x0D
    
    internal var connectionCompleted :  Completion?
    internal var initSessionCompletion: Completion?
    internal var onDiscoverCompletion :  CompletionWithJSONResponse?

    
    static var   DELAY : UInt32 = 1000;   // timeout resolution in millionths of second
    static var   NB_MAX_RETRY : Int = 50;
    
    init(plugin: NfcPlugin) {
        self.plugin = plugin
        super.init()
    }
    
    func initSession( pollingOption: NFCTagReaderSession.PollingOption, alertMessage: String, completed: Completion? ) {
        return self.initSession(pollingOption: pollingOption, alertMessage: alertMessage, completed: completed, onDiscover: nil)
    }
    
    func initSession( pollingOption: NFCTagReaderSession.PollingOption, alertMessage: String, onDiscover: CompletionWithJSONResponse?) {
        return self.initSession(pollingOption: pollingOption, alertMessage: alertMessage, completed: nil, onDiscover: onDiscover)
    }
    
    func initSession( pollingOption: NFCTagReaderSession.PollingOption, alertMessage: String, completed: Completion?, onDiscover: CompletionWithJSONResponse? ) {
        connectionCompleted = completed
        onDiscoverCompletion = onDiscover
        
        if NFCNDEFReaderSession.readingAvailable {
            comSession = NFCTagReaderSession(pollingOption: pollingOption, delegate: self, queue: nil)
            comSession?.alertMessage = alertMessage
            comSession?.begin()
        } else {
            completed?(NFCReaderError.readerTransceiveErrorSessionInvalidated as? Error)
        }
    }
    
    func initSession( pollingOption: NFCTagReaderSession.PollingOption, alertMessage: String, initSessionCompletion: Completion?, onDiscover: CompletionWithJSONResponse? ) {
        self.initSessionCompletion = initSessionCompletion
        return self.initSession(pollingOption: pollingOption, alertMessage: alertMessage, completed: nil, onDiscover: onDiscover)
    }

    func invalidateSession( message :String) {
        comSession?.alertMessage = message
        comSession?.invalidate()
        tag = nil
    }
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // If necessary, you may perform additional operations on session start.
        // At this point RF polling is enabled.
        if let actualInitSessionCompletion = initSessionCompletion {
            actualInitSessionCompletion(nil)
            initSessionCompletion = nil //do not keep session completion
        }
        printNFC( "tagReaderSessionDidBecomeActive" )
    }
 
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
       // If necessary, you may handle the error. Note session is no longer valid.
        // You must create a new session to restart RF polling.
        printNFC( "tagReaderSession:didInvalidateWithError - \(error)" )
        if let actualInitSessionCompletion = initSessionCompletion {
            actualInitSessionCompletion(error)
            initSessionCompletion = nil //do not keep session completion
        }
        connectionCompleted?(error)
        clear()
        self.comSession = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        printNFC( "tagReaderSession:didDectectTag" )
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
        
        self.tag = tag
        
        if let onDiscover = self.onDiscoverCompletion {
            
            Task {
                self.onDiscoverCompletion?(await self.createJSON(tag: tag), nil)
            }

        }
        
        if let connectionCompletion = self.connectionCompleted {
            connect(tech: nil, connectionCompletion: connectionCompletion)
        }

    }
    
        //full transparent mode
    
    @available(iOS 14.0, *)
    func transceiveRaw(request: Data, completed: @escaping (Data?, Error?) -> (), nbTry: Int = NB_MAX_RETRY) {
        guard (request.count >= 2) else {
            completed(nil, NFCReaderError(NFCReaderError.readerErrorInvalidParameterLength))
            return
        }
        
        switch self.tag {
        case .iso15693(let iso15693Tag):
            
            let flags = Int(request[0])
            let commandCode = Int(request[1])
            let dataToSend = request.dropFirst(2)
            
            printNFC("TRANSCEIVE RAW SEND \(request.hexEncodedString())")
            printNFC("TRANSCEIVE RAW SEND ON ISO15TAG TRY \(nbTry), SESSION READY \(String(describing: comSession?.isReady))")
            
            iso15693Tag.sendRequest(requestFlags: flags, commandCode: commandCode, data: dataToSend, resultHandler: {(result: Result<(NFCISO15693ResponseFlag, Data?), any Error>) in

                printNFC("SEND_REQUEST_CALLBACK")
                switch result {
                case .success((let flag, let data)):
                    let firstByteBuffer = withUnsafeBytes(of: flag.rawValue) { Data($0)}
                    var resultData = Data(firstByteBuffer)
                    if let nonNilData = data {
                        resultData.append(nonNilData)
                    }
                    
                    //Last delay to let ST25DV "breathe"
                    //usleep(1000*NFCTagReader.DELAY)
                    
                    printNFC("TRANSCEIVE RAW RETURN \(resultData.hexEncodedString())")
                    completed(resultData, nil)
                    return
                case .failure(let error):
                    printNFC("TRANSCEIVE RAW ERROR \(error.localizedDescription), TRY \(nbTry)")
                    if (nbTry >= 0) {
                        usleep(NFCTagReader.DELAY)
                        return self.transceiveRaw(request: request, completed: completed, nbTry: nbTry - 1)
                    }
                    
                    completed(nil, error)
                    return
                }
            })
            break
        case .iso7816(let iso7816Tag):
            printNFC("TRANSCEIVE RAW SEND ON iso7816Tag TRY \(nbTry), SESSION READY \(String(describing: comSession?.isReady))")
            
            guard let requestAPDU = NFCISO7816APDU(data: request) else {
                completed(nil, NFCReaderError(NFCReaderError.readerErrorInvalidParameterLength) )
                return
            }
            
            iso7816Tag.sendCommand(apdu: requestAPDU, resultHandler: {(result: Result<NFCISO7816ResponseAPDU, any Error>) in

                printNFC("SEND_REQUEST_CALLBACK")
                switch result {
                case .success(let response):
                    var resultData = Data()
                    
                    if let nonNilData = response.payload {
                        resultData.append(nonNilData)
                    }
                    
                    resultData.append(response.statusWord1)
                    resultData.append(response.statusWord2)
                    

                    printNFC("TRANSCEIVE RAW RETURN \(resultData.hexEncodedString())")
                    completed(resultData, nil)
                    return
                case .failure(let error):
                    printNFC("TRANSCEIVE RAW ERROR \(error.localizedDescription), TRY \(nbTry)")
                    if (error is NFCReaderError) {
                        if (!iso7816Tag.isAvailable) {
                            completed(nil, error)
                            return
                        }
                    }
                    if (nbTry >= 0) {
                        usleep(NFCTagReader.DELAY)
                        return self.transceiveRaw(request: request, completed: completed, nbTry: nbTry - 1)
                    }
                    completed(nil, error)
                    return
                }
            })
        default:
            completed(nil, NFCReaderError(NFCReaderError.readerTransceiveErrorTagConnectionLost))
            return
        }
        
 
    }
    
    func connect(tech: NfcTech?, connectionCompletion: Completion?) {
        
        // Check if a tag has been detected
        guard let tag = self.tag else {
            connectionCompletion?(NFCReaderError( NFCReaderError.readerTransceiveErrorTagNotConnected ))
            return
        }
        // Connect to tag
        if let actualTech = tech {
            switch actualTech {
            case NfcTech.NfcV:
                guard case .iso15693(_) = self.tag else {
                    connectionCompletion?(NFCReaderError( NFCReaderError.readerErrorInvalidParameter ))
                    return
                }
                break
            case NfcTech.IsoDep:
                fallthrough
            case NfcTech.NfcA:
                fallthrough
            case NfcTech.NfcB:
                guard case .iso7816(_) = self.tag else {
                    connectionCompletion?(NFCReaderError( NFCReaderError.readerErrorInvalidParameter ))
                    return
                }
                break
            default:
                connectionCompletion?(NFCReaderError( NFCReaderError.readerErrorInvalidParameter ))
                return
            }
        }
        self.connectionCompleted = connectionCompletion

        self.comSession?.connect(to: tag) { [weak self] (error: Error?) in
            guard let strongSelf = self  else {
                return;
            }

            if error != nil {
                let error = NFCReaderError( NFCReaderError.readerTransceiveErrorTagNotConnected )
                strongSelf.invalidateSession( message: error.localizedDescription  )
                strongSelf.connectionCompleted?(error)
                strongSelf.connectionCompleted = nil
                return
            }
            printNFC( "connected to tag" )
            strongSelf.tag = tag
            strongSelf.connectionCompleted?(nil)
        }
    }
    
    func clear() {
        self.tag = nil
        self.connectionCompleted = nil
    }
}

@available(iOS 13.0, *)
extension NFCTagReader {
    
    

    func transceiveTap(request: Data, completed: @escaping (Data?, Error?)->()){
       

        checkMBEnabled( completed: { ( error: Error?) in
                if nil != error {
                    self.invalidateSession( message: error?.localizedDescription ?? "Error" )
                    completed( nil, error )
                    return
                }
                printNFC( "Com enabled" )
                self.sendRequest( request: request,
                    nbTry: NFCTagReader.NB_MAX_RETRY,
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
        guard case let .iso15693(iso15693tag) = self.tag else {
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
        printNFC( "Send - \(parameters.hexEncodedString())" )

        iso15693tag.customCommand(requestFlags: [.highDataRate],
                          customCommandCode: 0xAA,
            customRequestParameters:  parameters,
            completionHandler: { (response: Data?, error: Error?) in
                if nil != error {
                    usleep(NFCTagReader.DELAY)
                    self.sendRequest( request: request, nbTry: nbTry - 1, completed: completed )
                    return
                }
                    usleep(NFCTagReader.DELAY * 10) // free ST25DV for SPI
                    self.readResponse( nbTry: nbTry , completed: completed)
            })
        
    }
    
    func readResponse( nbTry: Int, completed: @escaping (Data?, Error?)->() ) {
        
        guard case let .iso15693(iso15693tag) = self.tag else {
            let error = NFCReaderError( NFCReaderError.readerTransceiveErrorTagNotConnected )
            invalidateSession( message: error.localizedDescription  )
            completed( nil, error )
            return;
        }
        
        //We have tried enough timeout and return
        if (nbTry <= 0){
            printNFC( "Read Abandonned" )
            let error = NFCReaderError( NFCReaderError.readerTransceiveErrorRetryExceeded )
            invalidateSession( message: error.localizedDescription  )
            completed( nil, error )
            return;
        }
        
        printNFC( "Read \(nbTry)" )
  
        //check Mailbox
        iso15693tag.customCommand(requestFlags: [.highDataRate],
                          customCommandCode: 0xAD,
                          customRequestParameters:  Data(bytes: [UInt8(0x0D)], count: 1),
                          completionHandler: { (response: Data, error: Error?) in
                            if nil != error {
                                usleep(NFCTagReader.DELAY)
                                self.readResponse( nbTry: nbTry - 1, completed: completed )
                                return
                            }
                            
                            printNFC( "Read response" )
                            
                            if ( (response.count >= 1) && ( (response[0]&0x1) != 0 ) && ( (response[0]&0x2) != 0  )){

                                printNFC( "Read Value - \(Data(response).hexEncodedString())" )
                                iso15693tag.customCommand(requestFlags: [.highDataRate],
                                                  customCommandCode: 0xAC,
                                                  customRequestParameters:  Data(bytes: [UInt8(0), UInt8(0)], count: 2),
                                                  completionHandler: { (response: Data, error: Error?) in
                                                    if nil != error {
                                                        self.invalidateSession( message: error?.localizedDescription ?? "Error" )
                                                        completed( nil, error )
                                                        return
                                                    }
                                                    printNFC( "got Value - \(Data(response).hexEncodedString())" )
                                                    completed(response,nil)
                                                    return
                                })
                               
                            }
                            else {
                                usleep(NFCTagReader.DELAY)
                                self.readResponse( nbTry: nbTry - 1, completed: completed )
                            }
                        
            })
        
        
    }
    
    func checkMBEnabled(completed: @escaping (Error?)->()) {
        guard case let .iso15693(iso15693tag) = self.tag else {
            let error = NFCReaderError( NFCReaderError.readerTransceiveErrorTagNotConnected )
             invalidateSession( message: error.localizedDescription  )
             completed( error )
            return;
        }
        
        //Read Config
        iso15693tag.customCommand(requestFlags: [.highDataRate],
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
                    iso15693tag.customCommand(requestFlags: [.highDataRate],
                        customCommandCode: 0xAE,
                        customRequestParameters:  Data(bytes: [UInt8(0x0D), UInt8(0x00)], count: 2),
                        completionHandler: { (response: Data, error: Error?) in
                            if nil != error {
                                self.invalidateSession( message: error?.localizedDescription ?? "Error" )
                                completed( error )
                                return
                            }
                            
                            //enable
                        iso15693tag.customCommand(requestFlags: [.highDataRate],
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
    
    func sendTap( request: String, completed: @escaping (Data?,Error?)->() ) {
        
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
        printNFC( "Transceive - \(requestData.hexEncodedString())" )
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
    
    func createJSON(tag: NFCTag) async -> [AnyHashable: Any] {
        try? await self.comSession?.connect(to: tag)
        return await tag.toJSON(isTapDiscoveryEnabled: self.plugin.isTapDiscoveryEnabled())
    }
}
    
