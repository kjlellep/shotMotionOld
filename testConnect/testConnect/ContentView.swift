//
//  ContentView.swift
//  testConnect
//
//  Created by Karl Lellep on 05.04.2021.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var model = ViewModelPhone()
    @State var reachable = "No"
    
    @State var messageText = ""
    
    var body: some View {
        VStack{
            Spacer()
            
            Text("Reachable \(reachable)")
            
            Button(action: {
                if self.model.session.isReachable{
                    self.reachable = "Yes"
                }
                else{
                    self.reachable = "No"
                }
                
            }) {
                Text("Update")
            }
            Spacer()
            VStack{
                Text(self.model.messageText5).font(.title)
                Text(self.model.messageText4).font(.title)
                Text(self.model.messageText3).font(.title)
                Text(self.model.messageText2).font(.title)
                Text(self.model.messageText1).font(.title)
                Text(self.model.messageText0).font(.title)
            }
            Spacer()
            
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
