import CoreNFC

@available(iOS 13.0, *)
class NFCTagReader : NSObject, NFCTagReaderSessionDelegate  {

    typealias Completion = (Error?) -> ()
    typealias CompletionWithJSONResponse = ([AnyHashable: Any]?, Error?) -> ()
        
    internal var comSession: NFCTagReaderSession?
    internal var tag: NFCTag?

    static var   MB_CTRL_DYN : UInt8 = 0x0D
    
    internal var connectionCompleted :  Completion?
    internal var onDiscoverCompletion :  CompletionWithJSONResponse?

    
    static var   DELAY : UInt32 = 1000;   // timeout resolution in millionths of second
    static var   NB_MAX_RETRY : Int = 50;
    
    override init() {
        super.init()
    }
    
    func initSession( pollingOption: NFCTagReaderSession.PollingOption, alertMessage: String, completed: @escaping (Error?)->() ) {
        return self.initSession(pollingOption: pollingOption, alertMessage: alertMessage, completed: completed, onDiscover: nil)
    }
    
    func initSession( pollingOption: NFCTagReaderSession.PollingOption, alertMessage: String, completed: @escaping (Error?)->(), onDiscover: CompletionWithJSONResponse? ) {
        connectionCompleted = completed
        onDiscoverCompletion = onDiscover
        
        if NFCNDEFReaderSession.readingAvailable {
            comSession = NFCTagReaderSession(pollingOption: pollingOption, delegate: self, queue: nil)
            comSession?.alertMessage = alertMessage
            comSession?.begin()
        } else {
            completed(NFCReaderError.readerTransceiveErrorSessionInvalidated as? Error)
        }
    }

    func invalidateSession( message :String) {
        comSession?.alertMessage = message
        comSession?.invalidate()
        tag = nil
    }
    
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
        self.tag = nil
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
        }
    }
    
    

}
