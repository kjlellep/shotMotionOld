//
//  ViewModelPhone.swift
//  testConnect
//
//  Created by Karl Lellep on 05.04.2021.
//

import Foundation
import WatchConnectivity

class ViewModelPhone : NSObject,  WCSessionDelegate, ObservableObject{
    var session: WCSession
    
    @Published var messageText = ""
    @Published var messageText0 = ""
    @Published var messageText1 = ""
    @Published var messageText2 = ""
    @Published var messageText3 = ""
    @Published var messageText4 = ""
    @Published var messageText5 = ""
    
    
    init(session: WCSession = .default){
        self.session = session
        super.init()
        self.session.delegate = self
        session.activate()
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            
            let received = message["message"] as? String ?? "Unknown"
            
            if (received == "noise" || received == "shot") {
                let date = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd hh:mm:ss"
                let dateSuffix = formatter.string(from: date)
                
                self.messageText5 = self.messageText4
                self.messageText4 = self.messageText3
                self.messageText3 = self.messageText2
                self.messageText2 = self.messageText1
                self.messageText1 = self.messageText0
                self.messageText0 = received + " " + dateSuffix
            }
            else {
                let date = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd hh-mm-ss"
                let dateSuffix = formatter.string(from: date)
                
                if (received == "endunlabeled") {
                    self.printToFile(fileName: dateSuffix + "-1")
                }
                else if (received == "endlabeled") {
                    self.printToFile(fileName: dateSuffix + "-2")
                }
                else {
                    self.messageText += received
                }
            }
            
            
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths [0]
    }
    
    func printToFile(fileName: String) {
        let motionFile = self.getDocumentsDirectory().appendingPathComponent("motionData " + fileName)

        do {
            try self.messageText.write(to: motionFile, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("Error printing motion data file: " + "motionData " + fileName)
        }
        self.messageText = ""
    }
    
}

