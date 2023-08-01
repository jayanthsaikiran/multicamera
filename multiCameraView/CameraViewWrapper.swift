//
//  CameraControllerWrapper.swift
//  multiCameraView
//
//  Created by DiegoGuarin on 7/17/23.
//

import SwiftUI

struct CameraViewWrapper: UIViewControllerRepresentable {
    @Binding var desiredResolution: String
    @Binding var desiredFPS: String
    @Binding var desiredExtension: String
    @Binding var desiredCodec: String
//    @Binding var selectedFPS: Int
    
    typealias UIViewControllerType = CameraView
 
    func makeUIViewController(context: UIViewControllerRepresentableContext<CameraViewWrapper>) -> CameraViewWrapper.UIViewControllerType {
        return CameraView(desiredResolution: $desiredResolution, desiredFPS: $desiredFPS, desiredExtension: $desiredExtension, desiredCodec: $desiredCodec)
       }
    
    func updateUIViewController(_ uiViewController: CameraViewWrapper.UIViewControllerType, context: UIViewControllerRepresentableContext<CameraViewWrapper>) {
        //
    }
}

//#Preview {
//    CameraControllerWrapper()
//}
