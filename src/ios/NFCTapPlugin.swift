//
//  NFCTapPlugin.swift
//  NFC
//
//  Created by dev@iotize.com on 23/07/2019.
//  Copyright © 2019 dev@iotize.com. All rights reserved.
//

import Foundation
import UIKit
import CoreNFC

// Main class handling the plugin functionalities.
@objc(NfcPlugin) class NfcPlugin: CDVPlugin {
    var nfcController: NSObject? // ST25DVReader downCast as NSObject for iOS version compatibility
    var ndefController: NFCNDEFDelegate?
    var lastError: Error?
    var channelCommand: CDVInvokedUrlCommand?
    var isListeningNDEF = false
    
    private var _isTapDiscoveryEnabled: Bool!
    
    override func pluginInitialize(){
        //Need to be initialized here, otherwise it is not set to true
        self._isTapDiscoveryEnabled = true
    }
    
    func sendSuccess(command: CDVInvokedUrlCommand) {
        let pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    // helper to return a string
    func sendSuccess(command: CDVInvokedUrlCommand, result: String) {
        let pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: result
        )
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    // helper to return a boolean
    private func sendSuccess(command: CDVInvokedUrlCommand, result: Bool) {
        let pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: result
        )
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    // helper to return a String with keeping the callback
    func sendSuccessWithResponse(command: CDVInvokedUrlCommand, result: String) {
        let pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: result
        )
        pluginResult!.setKeepCallbackAs(true)
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    // helper to send back an error
    func sendError(command: CDVInvokedUrlCommand, result: String) {
        let pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR,
            messageAs: result
        )
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    //IoTize Tap specific connect. Opens reading session and connect to tap on discover
    @objc(connect:)
    func connect(command: CDVInvokedUrlCommand) {
        printNFC("connect")
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "connect is only available on iOS 13+")
            return
        }

        var alertMessage = "Bring your phone close to the Tap."
        
        if let alertMessageFromCommand = command.argument(at:0) as? String {
            alertMessage = alertMessageFromCommand
        }
        
        
        DispatchQueue.main.async {
            printNFC("Begin session \(String(describing: self.nfcController))")
            if self.nfcController == nil {
                self.nfcController = NFCTagReader(plugin: self)
            }
            
            if let isSessionReady = (self.nfcController as! NFCTagReader).comSession?.isReady {
                if isSessionReady {
                    // We reuse the current session
                    (self.nfcController as! NFCTagReader).connect(tech: NfcTech.NfcV, connectionCompletion: {
                        (error: Error?) -> Void in

                        DispatchQueue.main.async {
                            if error != nil {
                                self.sendError(command: command, result: error!.localizedDescription)
                            } else {
                                self.sendSuccess(command: command, result: "")
                            }
                        }
                    })
                    return
                }
            }

            (self.nfcController as! NFCTagReader).initSession(pollingOption: [.iso15693], alertMessage: alertMessage, completed: {
                (error: Error?) -> Void in

                DispatchQueue.main.async {
                    if error != nil {
                        self.sendError(command: command, result: error!.localizedDescription)
                    } else {
                        self.sendSuccess(command: command, result: "")
                    }
                }
            })
        }
    }

    @objc(close:)
    func close(command: CDVInvokedUrlCommand) {
        printNFC("close")
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "close is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            if self.nfcController == nil {
                self.sendError(command: command, result: "no session to terminate")
                return
            }

            (self.nfcController as! NFCTagReader).invalidateSession(message: "Session Ended!")
            self.nfcController = nil
        }
    }

    @objc(transceiveTap:)
    func transceiveTap(command: CDVInvokedUrlCommand) {
        printNFC("transceiveTap")

        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "transceive is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            printNFC("sending ...")
            if self.nfcController == nil {
                self.sendError(command: command, result: "not connected")
                return
            }

            // we need data to send
            if command.arguments.count <= 0 {
                self.sendError(command: command, result: "SendRequest parameter error")
                return
            }

            guard let data: NSData = command.arguments[0] as? NSData else {
                self.sendError(command: command, result: "Tried to transceive empty string")
                return
            }
            let request = data.map { String(format: "%02x", $0) }
                .joined()
            printNFC("send request  - \(request)")

            (self.nfcController as! NFCTagReader).sendTap(request: request, completed: {
                (response: Data?, error: Error?) -> Void in

                DispatchQueue.main.async {
                    if error != nil {
                        self.lastError = error
                        self.sendError(command: command, result: "Tag was lost")
                    } else {
                        printNFC("responded \(response!.hexEncodedString())")
                        self.sendSuccess(command: command, result: response!.hexEncodedString())
                    }
                }
            })
        }
    }
    
    @objc(registerTag:)
    func registerTag(command: CDVInvokedUrlCommand) {
        printNFC("registerTag")
        registerChannel()
        //No need to register, NFC tag discovery handled in sessions
        sendSuccess(command: command)
    }
    
    @objc(registerTapDevice:)
    func registerTapDevice(command: CDVInvokedUrlCommand) {
        printNFC("registerTapDevice")
        registerChannel()
        //No need to register, NFC tag discovery handled in sessions
        sendSuccess(command: command)
    }

    @objc(registerNdef:)
    func registerNdef(command: CDVInvokedUrlCommand) {
        printNFC("registerNdef")
        registerChannel()
        sendSuccess(command: command)
    }

    @objc(registerMimeType:)
    func registerMimeType(command: CDVInvokedUrlCommand) {
        printNFC("registerMimeType")
        registerChannel()
        //No need to register, NFC tag discovery handled in sessions
        sendSuccess(command: command, result: "NDEF Listener is on")
    }

    @objc(beginNDEFSession:)
    func beginNDEFSession(command: CDVInvokedUrlCommand) {
        printNFC("beginNDEFSession")
        
        DispatchQueue.main.async {
            printNFC("Begin NDEF reading session")

            if self.ndefController == nil {
                var message: String?
                if command.arguments.count != 0 {
                    message = command.arguments[0] as? String ?? ""
                }
                self.ndefController = NFCNDEFDelegate(completed: {
                    (response: [AnyHashable: Any]?, error: Error?) -> Void in
                    DispatchQueue.main.async {
                        printNFC("handle NDEF")
                        if error != nil {
                            self.lastError = error
                            self.sendError(command: command, result: error!.localizedDescription)
                        } else {
                            // self.sendSuccess(command: command, result: response ?? "")
                            self.sendThroughChannel(jsonDictionary: response ?? [:])
                        }
                        self.ndefController = nil
                    }
                }, message: message)
            }
        }
    }

    @objc(invalidateNDEFSession:)
    func invalidateNDEFSession(command: CDVInvokedUrlCommand) {
        printNFC("invalidateNDEFSession")

        guard #available(iOS 11.0, *) else {
            sendError(command: command, result: "close is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            guard let session = self.ndefController?.session else {
                self.sendError(command: command, result: "no session to terminate")
                return
            }

            session.invalidate()
            self.nfcController = nil
            self.sendSuccess(command: command, result: "Session Ended!")
        }
    }

    @objc(channel:)
    func channel(command: CDVInvokedUrlCommand) {
        printNFC("channel")
        DispatchQueue.main.async {
            printNFC("Creating NDEF Channel")
            self.channelCommand = command
            self.sendThroughChannel(message: "Did create NDEF Channel")
        }
    }

    func sendThroughChannel(message: String) {
        guard let command: CDVInvokedUrlCommand = self.channelCommand else {
            printNFC("Channel is not set")
            return
        }
        guard let response = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: message) else {
            printNFC("sendThroughChannel Did not create CDVPluginResult")
            return
        }

        response.setKeepCallbackAs(true)
        commandDelegate!.send(response, callbackId: command.callbackId)
    }

    func sendThroughChannel(jsonDictionary: [AnyHashable: Any]) {
        guard let command: CDVInvokedUrlCommand = self.channelCommand else {
            printNFC("Channel is not set")
            return
        }
        guard let response = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: jsonDictionary) else {
            printNFC("sendThroughChannel Did not create CDVPluginResult")
            return
        }

        response.setKeepCallbackAs(true)
        commandDelegate!.send(response, callbackId: command.callbackId)

//        self.sendSuccessWithResponse(command: command, result: message)
    }

    @objc(enabled:)
    func enabled(command: CDVInvokedUrlCommand) {
        printNFC("enabled")

        guard #available(iOS 11.0, *) else {
            sendError(command: command, result: "enabled is only available on iOS 11+")
            return
        }
        let enabled = NFCReaderSession.readingAvailable
        sendSuccess(command: command, result: enabled)
    }
    
    //full transparent mode
    @objc(transceive:)
    func transceive(command: CDVInvokedUrlCommand) {
        printNFC("transceive")

        guard #available(iOS 14.0, *) else {
            sendError(command: command, result: "Tranparent transceive is only available in iOS 14+")
            return
        }
        
        DispatchQueue.main.async {
            printNFC("sending ...")
            if self.nfcController == nil {
                self.sendError(command: command, result: "no session available")
                return
            }

            // we need data to send
            if command.arguments.count <= 0 {
                self.sendError(command: command, result: "transceive parameter error")
                return
            }

            guard let data: Data = command.arguments[0] as? Data else {
                self.sendError(command: command, result: "Tried to transceive empty buffer")
                return
            }

            (self.nfcController as! NFCTagReader).transceiveRaw(request: data, completed: {
                (response: Data?, error: Error?) -> Void in

                DispatchQueue.main.async {
                    if error != nil {
                        self.lastError = error
                        self.sendError(command: command, result: error!.localizedDescription)
                    } else {
                        printNFC("responded \(response!.hexEncodedString())")
                        self.sendSuccess(command: command, result: response!.hexEncodedString())
                    }
                }
            })
        }
    }
    
    @objc(beginSessionFromTech:)
    func beginSessionFromTech(command: CDVInvokedUrlCommand) {
        printNFC("beginSessionFromTech")

//        self.nfcController = nil // Clear previous session, if any
        
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "connectRaw is only available on iOS 13+")
            return
        }
        var tech = ""
        
        if let techFromCommand = command.argument(at: 0) as? String {
            tech = techFromCommand
        }
        
        var pollingOption: NFCTagReaderSession.PollingOption = []
        
        if let techAsNfcTech = NfcTech(rawValue: tech) {
            switch (techAsNfcTech) {
            case .NfcV:
                pollingOption.insert(.iso15693)
                break
            case .IsoDep:
                fallthrough
            case .NfcA:
                fallthrough
            case .NfcB:
                pollingOption.insert(.iso14443)
                break
            case .AnyTag:
                pollingOption.insert(.iso14443)
                pollingOption.insert(.iso15693)
                break
            default:
                self.sendError(command: command, result: "Tech \(tech) not available")
                break
            }
        } else {
            self.sendError(command: command, result: "Invalid parameter \(tech)")
            return
        }
        
        var alertMessage = "Begin NFC Session"
        
        if let alertMessageFromCommand = command.argument(at:1) as? String {
            alertMessage = alertMessageFromCommand
        }
        
        DispatchQueue.main.async {
            printNFC("Begin session NFC \(String(describing: pollingOption))")
            if self.nfcController == nil {
                self.nfcController = NFCTagReader(plugin: self)
            }

            (self.nfcController as! NFCTagReader).initSession(pollingOption: pollingOption, alertMessage: alertMessage, initSessionCompletion: {
                (error: Error?) -> Void in

                DispatchQueue.main.async {
                    if error != nil {
                        printNFC("onBeginSessionFromTech error \(error!.localizedDescription)")
                        self.sendError(command: command, result: error!.localizedDescription)
                    } else {
                        printNFC("onBeginSessionFromTech sucess")
                        self.sendSuccess(command: command, result: "nfcV session started")
                    }
                }
            }, onDiscover: {(discovered: [AnyHashable: Any]?, error: Error?) -> Void in
                DispatchQueue.main.async {
                    if error != nil {
                        printNFC("onDiscover error \(error!.localizedDescription)")
                        self.sendError(command: command, result: error!.localizedDescription)
                    } else if (discovered != nil){
                        printNFC("onDiscover success")
                        self.sendThroughChannel(jsonDictionary: discovered!)
                    }
                }
            })
        }
    }
    
    @objc(endSession:)
    func endSession(command: CDVInvokedUrlCommand) {
        printNFC("endSession")

        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "endSession is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            guard let session = (self.nfcController as? NFCTagReader)?.comSession else {
                self.sendError(command: command, result: "no session to terminate")
                return
            }

            session.invalidate()
            self.nfcController = nil
            self.sendSuccess(command: command, result: "Session Ended!")
        }
    }
    
    @objc(connectRaw:)
    func connectRaw(command: CDVInvokedUrlCommand) {
        printNFC("connectRaw")

        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "connectRaw is only available on iOS 13+")
            return
        }
        
        guard let tech = command.argument(at: 0) as? String else {
            self.sendError(command: command, result: "beginSessionFromTech parameter error: improper tech")
            return
        }
        
        guard let techAsNfcTech = NfcTech(rawValue: tech) else {
            self.sendError(command: command, result: "Tech \(tech) not available")
            return
        }
        
//        DispatchQueue.main.async {
            printNFC("sending ...")
            if self.nfcController == nil {
                self.sendError(command: command, result: "no session available")
                return
            }
            
            (self.nfcController as! NFCTagReader).connect(tech: techAsNfcTech, connectionCompletion: {
                (error: Error?) -> Void in

                DispatchQueue.main.async {
                    if error != nil {
                        self.sendError(command: command, result: error!.localizedDescription)
                    } else {
                        self.sendSuccess(command: command, result: "")
                    }
                }
            })
//        }
        
        
    }
    
    @objc(setTapDeviceDiscoveryEnabled:)
    func setTapDeviceDiscoveryEnabled(command: CDVInvokedUrlCommand) {
        printNFC("setTapDeviceDiscoveryEnabled")
        if let enabled = command.argument(at: 0) as? Bool {
            self._isTapDiscoveryEnabled = enabled
        } else {
            self._isTapDiscoveryEnabled = false
        }
    }
    
    func isTapDiscoveryEnabled() -> Bool {
        return self._isTapDiscoveryEnabled
    }
    
    func registerChannel() {
        isListeningNDEF = true // Flag for the AppDelegate
    }

}
