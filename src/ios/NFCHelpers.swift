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
        return Data(bytes: bytes, count:bytes.count)
    }
    
}

public extension Data {
    
    func hexEncodedString() -> String {
        let format = "%02hhX"
        return map { String(format: format, $0) }.joined()
    }
}

extension NFCISO15693Tag {

    func toJSON(ndefMessage: NFCNDEFMessage?) -> [AnyHashable: Any] {
    
        var returnedJSON: NSMutableDictionary
        
        if let ndef = ndefMessage {
            returnedJSON = ndef.ndefMessageToJSON()
            returnedJSON.setValue("nfc-tap-device", forKey: "type")
            
            let tapInfo = NSMutableDictionary()
            tapInfo.setValue(false, forKey: "nfcPairingDone")
            
            returnedJSON.setValue(tapInfo, forKey: "tap")
        } else {
            returnedJSON = NSMutableDictionary()
            let wrapper = NSMutableDictionary()
            wrapper.setValue("tag", forKey: "type")
            
            wrapper.setValue(["NfcV"], forKey: "techTypes")
            
            returnedJSON.setValue(wrapper, forKey: "tag")
            returnedJSON.setValue("tag", forKey: "type")
        }
        if let tagObject = returnedJSON.object(forKey: "tag") as? NSMutableDictionary {
            tagObject.setValue([UInt8](self.identifier) , forKey: "id")
        }

        return returnedJSON as! [AnyHashable : Any]
    }
}

extension NFCNDEFMessage {
    func ndefMessageToJSON() -> NSMutableDictionary {
        let array = NSMutableArray()
        for record in self.records {
            let recordDictionary = self.ndefToNSDictionary(record: record)
            array.add(recordDictionary)
        }
        let wrapper = NSMutableDictionary()
        
        wrapper.setValue(array, forKey: "ndefMessage")
        wrapper.setValue("ndef", forKey: "type")
        wrapper.setValue(["NfcV", "Ndef"], forKey: "techTypes")
        
        let returnedJSON = NSMutableDictionary()
        
        returnedJSON.setValue("ndef", forKey: "type")
        returnedJSON.setValue(wrapper, forKey: "tag")

        return returnedJSON
    }
    
    func ndefMessageToJSON() -> [AnyHashable: Any] {
        let json: NSMutableDictionary = self.ndefMessageToJSON()
        return json as! [AnyHashable: Any]
    }
    
    func ndefToNSDictionary(record: NFCNDEFPayload) -> NSDictionary {
        let dict = NSMutableDictionary()
        dict.setValue([record.typeNameFormat.rawValue], forKey: "tnf")
        dict.setValue([UInt8](record.type), forKey: "type")
        dict.setValue([UInt8](record.identifier), forKey: "id")
        dict.setValue([UInt8](record.payload), forKey: "payload")
        
        return dict
    }
}

