//
//  NFCNDEFDelegate.swift
//  NFC
//
//  Created by dev@iotize.com on 05/08/2019.
//  Copyright © 2019 dev@iotize.com. All rights reserved.
//

import Foundation
import CoreNFC

class NFCNDEFDelegate: NSObject, NFCNDEFReaderSessionDelegate {
    var session: NFCNDEFReaderSession?
    var completed: ([AnyHashable : Any]?, Error?) -> ()
    
    init(completed: @escaping ([AnyHashable: Any]?, Error?) -> (), message: String?) {
        self.completed = completed
        super.init()
        self.session = NFCNDEFReaderSession.init(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        if (self.session == nil) {
            self.completed(nil, "NFC is not available" as? Error);
            return
        }
        self.session!.alertMessage = message ?? ""
        self.session!.begin()
    }
    
    func readerSession(_: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            self.fireNdefEvent(message: message)
        }
        self.session?.invalidate()
    }
    
    func readerSession(_: NFCNDEFReaderSession, didInvalidateWithError _: Error) {
        completed(nil, "NFCNDEFReaderSession error" as? Error)
    }
    
    func readerSessionDidBecomeActive(_: NFCNDEFReaderSession) {
        print("NDEF Reader session active")
    }
    
    func fireNdefEvent(message: NFCNDEFMessage) {
        let response = message.ndefMessageToJSON()
        completed(response, nil)
    }
    
    
    
}

extension NFCNDEFMessage {
    func ndefMessageToJSON() -> [AnyHashable: Any] {
        let array = NSMutableArray()
        for record in self.records {
            let recordDictionary = self.ndefToNSDictionary(record: record)
            array.add(recordDictionary)
        }
        let wrapper = NSMutableDictionary()
        wrapper.setObject(array, forKey: "ndefMessage" as NSString)
        
        let returnedJSON = NSMutableDictionary()
        returnedJSON.setValue("ndef", forKey: "type")
        returnedJSON.setObject(wrapper, forKey: "tag" as NSString)

        return returnedJSON as! [AnyHashable : Any]
    }
    
    func ndefToNSDictionary(record: NFCNDEFPayload) -> NSDictionary {
        let dict = NSMutableDictionary()
        dict.setObject([record.typeNameFormat.rawValue], forKey: "tnf" as NSString)
        dict.setObject([UInt8](record.type), forKey: "type" as NSString)
        dict.setObject([UInt8](record.identifier), forKey: "id" as NSString)
        dict.setObject([UInt8](record.payload), forKey: "payload" as NSString)
        
        return dict
    }
}
