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

    @objc(connect:)
    func connect(command: CDVInvokedUrlCommand) {
        print("CONNECT NFC")
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "connect is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            print("Begin session \(String(describing: self.nfcController))")
            if self.nfcController == nil {
                self.nfcController = ST25DVReader()
            }

            (self.nfcController as! ST25DVReader).initSession(pollingOption: [.iso15693], alertMessage: "Bring your phone close to the Tap.", completed: {
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
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "close is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            if self.nfcController == nil {
                self.sendError(command: command, result: "no session to terminate")
                return
            }

            (self.nfcController as! NFCTagReader).invalidateSession(message: "Sesssion Ended!")
            self.nfcController = nil
        }
    }

    @objc(transceiveTap:)
    func transceiveTap(command: CDVInvokedUrlCommand) {
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "transceive is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            print("sending ...")
            if self.nfcController == nil {
                self.sendError(command: command, result: "no session available")
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
            print("send request  - \(request)")

            (self.nfcController as! ST25DVReader).send(request: request, completed: {
                (response: Data?, error: Error?) -> Void in

                DispatchQueue.main.async {
                    if error != nil {
                        self.lastError = error
                        self.sendError(command: command, result: error!.localizedDescription)
                    } else {
                        print("responded \(response!.hexEncodedString())")
                        self.sendSuccess(command: command, result: response!.hexEncodedString())
                    }
                }
            })
        }
    }
    
    @objc(registerTag:)
    func registerTag(command: CDVInvokedUrlCommand) {
        print("Registered NDEF Listener")
        //isListeningNDEF = true // Flag for the AppDelegate
        sendSuccess(command: command, result: "Tag Listener is on")
    }

    @objc(registerNdef:)
    func registerNdef(command: CDVInvokedUrlCommand) {
        print("Registered NDEF Listener")
        isListeningNDEF = true // Flag for the AppDelegate
        sendSuccess(command: command, result: "NDEF Listener is on")
    }

    @objc(registerMimeType:)
    func registerMimeType(command: CDVInvokedUrlCommand) {
        print("Registered Mi Listener")
        sendSuccess(command: command, result: "NDEF Listener is on")
    }

    @objc(beginNDEFSession:)
    func beginNDEFSession(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            print("Begin NDEF reading session")

            if self.ndefController == nil {
                var message: String?
                if command.arguments.count != 0 {
                    message = command.arguments[0] as? String ?? ""
                }
                self.ndefController = NFCNDEFDelegate(completed: {
                    (response: [AnyHashable: Any]?, error: Error?) -> Void in
                    DispatchQueue.main.async {
                        print("handle NDEF")
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
        DispatchQueue.main.async {
            print("Creating NDEF Channel")
            self.channelCommand = command
            self.sendThroughChannel(message: "Did create NDEF Channel")
        }
    }

    func sendThroughChannel(message: String) {
        guard let command: CDVInvokedUrlCommand = self.channelCommand else {
            print("Channel is not set")
            return
        }
        guard let response = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: message) else {
            print("sendThroughChannel Did not create CDVPluginResult")
            return
        }

        response.setKeepCallbackAs(true)
        commandDelegate!.send(response, callbackId: command.callbackId)
    }

    func sendThroughChannel(jsonDictionary: [AnyHashable: Any]) {
        guard let command: CDVInvokedUrlCommand = self.channelCommand else {
            print("Channel is not set")
            return
        }
        guard let response = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: jsonDictionary) else {
            print("sendThroughChannel Did not create CDVPluginResult")
            return
        }

        response.setKeepCallbackAs(true)
        commandDelegate!.send(response, callbackId: command.callbackId)

//        self.sendSuccessWithResponse(command: command, result: message)
    }

    @objc(enabled:)
    func enabled(command: CDVInvokedUrlCommand) {
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
        guard #available(iOS 14.0, *) else {
            sendError(command: command, result: "Tranparent transceive is only available in iOS 14+")
            return
        }
        
        DispatchQueue.main.async {
            print("sending ...")
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

            (self.nfcController as! ST25DVReader).transceiveRaw(request: data, completed: {
                (response: Data?, error: Error?) -> Void in

                DispatchQueue.main.async {
                    if error != nil {
                        self.lastError = error
                        self.sendError(command: command, result: error!.localizedDescription)
                    } else {
                        print("responded \(response!.hexEncodedString())")
                        self.sendSuccess(command: command, result: response!.hexEncodedString())
                    }
                }
            })
        }
    }
    
    @objc(beginSessionFromTech:)
    func beginSessionFromTech(command: CDVInvokedUrlCommand) {
        
//        self.nfcController = nil // Clear previous session, if any
        
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "NFC Tag Session is only available in iOS 13+")
            return
        }
        // we need data to send
        if command.arguments.count <= 0 {
            self.sendError(command: command, result: "beginSessionFromTech parameter error: missing tech")
            return
        }

        guard let tech = command.argument(at: 0) as? String else {
            self.sendError(command: command, result: "beginSessionFromTech parameter error: improper tech")
            return
        }
        switch tech {
        case "nfcV":
            DispatchQueue.main.async {
                print("Begin session \(String(describing: self.nfcController))")
                if self.nfcController == nil {
                    self.nfcController = ST25DVReader()
                }

                (self.nfcController as! ST25DVReader).initSession(pollingOption: [.iso15693], alertMessage: "Begin nfcV Session.", completed: {
                    (error: Error?) -> Void in

                    DispatchQueue.main.async {
                        if error != nil {
                            print("onBeginSessionFromTech error \(error!.localizedDescription)")
                            self.sendError(command: command, result: error!.localizedDescription)
                        } else {
                            print("onBeginSessionFromTech sucess")
                            self.sendSuccess(command: command, result: "nfcV session started")
                        }
                    }
                }, onDiscover: {(discovered: [AnyHashable: Any]?, error: Error?) -> Void in
                    DispatchQueue.main.async {
                        if error != nil {
                            print("onDiscover error \(error!.localizedDescription)")
                            self.sendError(command: command, result: error!.localizedDescription)
                        } else if (discovered != nil){
                            print("onDiscover success")
                            self.sendThroughChannel(jsonDictionary: discovered!)
                        }
                    }
                })
            }
            return
        default:
            self.sendError(command: command, result: "Unsupported tech \(tech)")
        }
    }
    
    @objc(endSession:)
    func endSession(command: CDVInvokedUrlCommand) {
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
}
