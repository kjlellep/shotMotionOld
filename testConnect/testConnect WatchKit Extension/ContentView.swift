//
//  ContentView.swift
//  testConnect WatchKit Extension
//
//  Created by Karl Lellep on 05.04.2021.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var model = ViewModelWatch()
    
    @EnvironmentObject var workoutSession: WorkoutManager
    @State var workoutInProgress = false
    
    var body: some View {
        
        VStack{
            Text(String(self.workoutInProgress))
                .padding()
            
            
            if !self.workoutInProgress {
                Button(action: {
                    self.workoutSession.startWorkout()
                    self.workoutInProgress = true
                }) {
                    Text("Start Workout")
                }
            }
            else {
                Button(action: {
                    self.workoutSession.endWorkout()
                    self.workoutInProgress = false
                }) {
                    Text("End Workout")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(WorkoutManager())
    }
}
