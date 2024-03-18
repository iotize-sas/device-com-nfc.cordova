
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

public extension Data {
    
    func hexEncodedString() -> String {
        let format = "%02hhX"
        return map { String(format: format, $0) }.joined()
    }
}
