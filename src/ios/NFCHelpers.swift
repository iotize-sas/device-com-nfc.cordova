import CoreNFC

public extension String {
    func dataFromHexString() -> Data {
        var bytes = [UInt8]()
        bytes.reserveCapacity(count / 2)
        
        var index = startIndex
        while index < endIndex {
            let next = self.index(index, offsetBy: 2)
            let byteString = String(self[index..<next])
            let byte = UInt8(byteString, radix: 16)!
            bytes.append(byte)
            index = next
        }

        return Data(bytes)
    }
}

public extension Data {
    
    func hexEncodedString() -> String {
        let format = "%02hhX"
        return map { String(format: format, $0) }.joined()
    }
}

public extension NFCISO15693Tag {
    
    func toJSON(ndefMessage: NFCNDEFMessage? = nil) -> [AnyHashable: Any] {
        
        let wrapper = NSMutableDictionary()
        wrapper.setValue([UInt8](self.identifier) , forKey: "id")
        
        let returnedJSON = NSMutableDictionary()
        returnedJSON.setValue("tag", forKey: "type")
        returnedJSON.setObject(wrapper, forKey: "tag" as NSString)
        
        

        return returnedJSON as! [AnyHashable : Any]
    }
}

public enum NfcTech: String {
    case IsoDep = "IsoDep" // Provides access to ISO-DEP (ISO 14443-4) properties and I/O operations on a Tag.
    case MifareClassic = "MifareClassic" // Provides access to MIFARE Classic properties and I/O operations on a Tag.
    case MifareUltralight = "MifareUltralight" // Provides access to MIFARE Ultralight properties and I/O operations on a Tag.
    case Ndef = "Ndef" // Provides access to NDEF content and operations on a Tag.
    case NdefFormatable = "NdefFormatable" // Provide access to NDEF format operations on a Tag.
    case NfcA = "NfcA" // Provides access to NFC-A (ISO 14443-3A) properties and I/O operations on a Tag.
    case NfcB = "NfcB" // Provides access to NFC-B (ISO 14443-3B) properties and I/O operations on a Tag.
    case NfcBarcode = "NfcBarcode" // Provides access to tags containing just a barcode.
    case NfcF = "NfcF" // Provides access to NFC-F (JIS 6319-4) properties and I/O operations on a Tag.
    case NfcV = "NfcV" // Provides access to NFC-V (ISO 15693) properties and I/O operations on a Tag.
    case AnyTag = ""
  }

@available(iOS 13.0, *)
public extension NFCTag {
        
    func toJSON(isTapDiscoveryEnabled: Bool) async -> [AnyHashable: Any] {
        let wrapper = NSMutableDictionary()
        var techTypes: [String] = []
        
        switch self {
        case .iso15693(let iso15693Tag):
            wrapper.setValue([UInt8](iso15693Tag.identifier) , forKey: "id")
            techTypes.append(NfcTech.NfcV.rawValue)
            do {
               let ndefMessage = try await iso15693Tag.readNDEF()
                techTypes.append(NfcTech.Ndef.rawValue)
                wrapper.setValue(ndefMessage.toJSONRecords(), forKey: "ndefMessage")
            } catch {
                print("ReadNDEF Error: \(error)")
            }
            
            break
        case .iso7816(let iso7816Tag):
            wrapper.setValue([UInt8](iso7816Tag.identifier) , forKey: "id")
            techTypes.append(NfcTech.NfcA.rawValue)
            if let ndefMessage = try? await iso7816Tag.readNDEF() {
                techTypes.append(NfcTech.Ndef.rawValue)
                wrapper.setValue(ndefMessage.toJSONRecords(), forKey: "ndefMessage")
            }
            break
        case .miFare(let miFareTag):
            wrapper.setValue([UInt8](miFareTag.identifier) , forKey: "id")
            switch miFareTag.mifareFamily {
            case .ultralight:
                techTypes.append(NfcTech.MifareUltralight.rawValue)
                break
            default:
                techTypes.append(NfcTech.MifareClassic.rawValue)
                break
            }
            if let ndefMessage = try? await miFareTag.readNDEF() {
                techTypes.append(NfcTech.Ndef.rawValue)
                wrapper.setValue(ndefMessage.toJSONRecords(), forKey: "ndefMessage")
            }
            break
        default:
            break
        }
        
        wrapper.setValue(techTypes, forKey: "techTypes")
        
        let returnedJSON = NSMutableDictionary()
        returnedJSON.setValue(wrapper, forKey: "tag")
        returnedJSON.setValue("tag", forKey: "type")
        if (isTapDiscoveryEnabled) {
            //For now, NFCTag is labelled as IoTizeTap if it is a 15693 tag with 4+ NDEF messages.
            //Cf Android implementation
            if (techTypes.contains(NfcTech.NfcV.rawValue)) {
                if let ndef = wrapper.value(forKey: "ndefMessage") {
                    if (ndef as! [[AnyHashable: Any]]).count >= 4 {
                        returnedJSON.setValue("nfc-tap-device", forKey: "type")
                        //Add tap property
                        let tapProp = NSMutableDictionary()
                        tapProp.setValue(false, forKey: "nfcPairingDone")
                        returnedJSON.setValue(tapProp, forKey: "tap")
                    }
                }
            }
        }
        return returnedJSON as! [AnyHashable : Any]

    }
}

public extension NFCNDEFMessage {
    func toJSONRecords() -> [[AnyHashable: Any]] {
        let array = NSMutableArray()
        for record in self.records {
            let recordDictionary = self.ndefToNSDictionary(record: record)
            array.add(recordDictionary)
        }
        return array as! [[AnyHashable: Any]]
    }
}

public func printNFC(_ message: String) {
    #if DEBUG
    print("NFC Plugin \(String(format: "%.3f", CACurrentMediaTime())): \(message)")
    #endif
}
