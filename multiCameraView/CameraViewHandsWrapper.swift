//
//  CameraViewHandsWrapper.swift
//  multiCameraView
//
//  Created by DiegoGuarin on 7/20/23.
//

import Foundation
import SwiftUI

struct CameraViewHandsWrapper: UIViewControllerRepresentable {
     
    @Binding var desiredResolution: String
    @Binding var desiredFPS: String
    @Binding var desiredExtension: String
    @Binding var desiredCodec: String
    var chilarity: String
//    @Binding var selectedFPS: Int
    
    typealias UIViewControllerType = CameraViewHands
 
    func makeUIViewController(context: UIViewControllerRepresentableContext<CameraViewHandsWrapper>) -> CameraViewHandsWrapper.UIViewControllerType {
        return CameraViewHands(desiredResolution: $desiredResolution, desiredFPS: $desiredFPS, desiredExtension: $desiredExtension, desiredCodec: $desiredCodec, chilarity:chilarity)
       }
    
    func updateUIViewController(_ uiViewController: CameraViewHandsWrapper.UIViewControllerType, context: UIViewControllerRepresentableContext<CameraViewHandsWrapper>) {
        //
    }
}
