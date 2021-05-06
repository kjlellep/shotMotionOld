//
//  WorkoutManager.swift
//  testConnect WatchKit Extension
//
//  Created by Karl Lellep on 07.04.2021.
//

import Foundation
import HealthKit
import CoreMotion
import Combine
import CoreML

let motionManager = CMMotionManager()

extension Date {
    var ticks: UInt64 {
        return UInt64((self.timeIntervalSince1970) * 10_000_000)
    }
}

class WorkoutManager: NSObject, ObservableObject {
    
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession!
    var builder: HKLiveWorkoutBuilder!
    
    var model = ViewModelWatch()
    
    struct ModelConstants {
        static let predictionWindowSize = 100
        static let sensorsUpdateInterval = 1.0 / 100.0
        static let stateInLength = 400
    }
    
    var mlModel: fullData!
    
    var currentIndexInPredictionWindow = 0
    
    let accelDataX = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let accelDataY = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let accelDataZ = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)

    let gyroDataX = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gyroDataY = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gyroDataZ = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)

    var stateOutput = try! MLMultiArray(shape:[ModelConstants.stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
    
    
    
    var running: Bool = false
    var cancellable: Cancellable?
    
    
    var motionOut = "accel x, accel y, accel z, gyro x, gyro y, gyro z, timestamp(ticks since 1970) \n"
    var labeledOut = "accel x, accel y, accel z, gyro x, gyro y, gyro z, timestamp(ticks since 1970), act_id \n"
    var motionBlock = [String]()
    
    
    func initModel() {
        let modelURL = Bundle.main.url(forResource: "fullData", withExtension: "mlmodelc")
        try! mlModel = fullData(contentsOf: modelURL!)
    }
    
    
    func requestAuthorization() {
        // Requesting authorization.
        /// - Tag: RequestAuthorization
        // The quantity type to write to the health store.
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        // The quantity types to read from the health store.
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        // Request authorization for those quantity types.
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            // Handle error.
        }
    }
    
    func workoutConfiguration() -> HKWorkoutConfiguration {
        /// - Tag: WorkoutConfiguration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor
        
        return configuration
    }
    
    func startWorkout() {
        self.running = true
        
        self.initModel()
        
        // Create the session and obtain the workout builder.
        /// - Tag: CreateWorkout
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: self.workoutConfiguration())
            builder = session.associatedWorkoutBuilder()
        } catch {
            // Handle any exceptions.
            return
        }
        
        // Setup session and builder.
        session.delegate = self
        builder.delegate = self
        
        // Set the workout builder's data source.
        /// - Tag: SetDataSource
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                     workoutConfiguration: workoutConfiguration())
        
        // Start the workout session and begin data collection.
        /// - Tag: StartSession
        session.startActivity(with: Date())
        builder.beginCollection(withStart: Date()) { (success, error) in
            // The workout has started.
        }
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.001
            motionManager.startDeviceMotionUpdates(to: .main) { (Data, error) in
                guard let motionData = Data, error == nil else {
                    return
                }
                
                self.addSamplesToDataArrays(motionData: motionData)
            }
        }
        
    }
    
    func addSamplesToDataArrays (motionData: CMDeviceMotion) {
        accelDataX[[currentIndexInPredictionWindow] as [NSNumber]] = motionData.userAcceleration.x as NSNumber
        accelDataY[[currentIndexInPredictionWindow] as [NSNumber]] = motionData.userAcceleration.y as NSNumber
        accelDataZ[[currentIndexInPredictionWindow] as [NSNumber]] = motionData.userAcceleration.z as NSNumber
        
        gyroDataX[[currentIndexInPredictionWindow] as [NSNumber]] = motionData.rotationRate.x as NSNumber
        gyroDataY[[currentIndexInPredictionWindow] as [NSNumber]] = motionData.rotationRate.y as NSNumber
        gyroDataZ[[currentIndexInPredictionWindow] as [NSNumber]] = motionData.rotationRate.z as NSNumber
        
        let currentData =
            String(format: "%f", motionData.userAcceleration.x) + ", " +
            String(format: "%f", motionData.userAcceleration.y) + ", " +
            String(format: "%f", motionData.userAcceleration.z) + ", " +
            String(format: "%f", motionData.rotationRate.x) + ", " +
            String(format: "%f", motionData.rotationRate.y) + ", " +
            String(format: "%f", motionData.rotationRate.z) + ", " +
            String(Date().ticks)
        
        self.motionBlock.append(currentData + ", ")
        self.motionOut += currentData + "\n"
        
        currentIndexInPredictionWindow += 1
        
        if (currentIndexInPredictionWindow == ModelConstants.predictionWindowSize) {
            if let predictedActivity = self.performModelPrediction() {

                // Use the predicted activity here
                
                for line in self.motionBlock {
                    self.labeledOut += line + predictedActivity + "\n"
                }
                
                    
                self.model.session.sendMessage(["message" : predictedActivity], replyHandler: nil) { (error) in
                    print(error.localizedDescription)
                }

                // Start a new prediction window
                currentIndexInPredictionWindow = 0
                self.motionBlock = [String]()
            }
        }
    }
    
    func performModelPrediction() -> String? {
        let modelPrediction = try! mlModel.prediction(accx: accelDataX, accy: accelDataY, accz: accelDataZ, gyrx: gyroDataX, gyry: gyroDataY, gyrz: gyroDataZ, stateIn: stateOutput)
        

        // Update the state vector
        stateOutput = modelPrediction.stateOut

        // Return the predicted activity - the activity with the highest probability
        return modelPrediction.act_id
    }
    
    func endWorkout() {
        motionManager.stopDeviceMotionUpdates()
        session.end()
        cancellable?.cancel()
        
        
        var unlabeled = self.splitToChunks(data: self.motionOut)
        unlabeled[unlabeled.count - 1] = unlabeled[unlabeled.count - 1] + "unlabeled"
        
        for chunk in unlabeled {
            self.model.session.sendMessage(["message" : chunk], replyHandler: nil) { (error) in
                print(error.localizedDescription)
            }
        }
        
        if self.motionBlock.count != 0 {
            for line in self.motionBlock {
                self.labeledOut += line + "noise\n"
            }
        }
        
        var labeled = self.splitToChunks(data: self.labeledOut)
        labeled[labeled.count - 1] = labeled[labeled.count - 1] + "labeled"
        for chunk in labeled {
            self.model.session.sendMessage(["message" : chunk], replyHandler: nil) { (error) in
                print(error.localizedDescription)
            }
        }
        
    }
    
    func resetWorkout() {
        // Reset the published values.
        DispatchQueue.main.async {
            self.motionOut = "accel x, accel y, accel z, gyro x, gyro y, gyro z, timestamp(ticks since 1970) \n"
            self.labeledOut = "accel x, accel y, accel z, gyro x, gyro y, gyro z, timestamp(ticks since 1970), act_id \n"
        }
    }
    
    func splitToChunks(data: String) -> Array<String> {
        let exploded = data.split(separator: "\n")
        
        var helper = ""
        var chunks = [String]()
        var counter = 0
        
        for line in exploded {
            if (counter < 650) {
                helper += line + "\n"
                counter += 1
                continue
            }
            if (counter == 650) {
                chunks.append(helper)
                helper = ""
                counter = 0
            }
        }
        chunks.append(helper)
        chunks.append("end")
        
        return chunks
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {
        // Wait for the session to transition states before ending the builder.
        /// - Tag: SaveWorkout
        if toState == .ended {
            print("The workout has now ended.")
            builder.endCollection(withEnd: Date()) { (success, error) in
                self.builder.finishWorkout { (workout, error) in
                    // Optionally display a workout summary to the user.
                    self.resetWorkout()
                }
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard type is HKQuantityType else {
                return // Nothing to do.
            }
        }
    }
}
