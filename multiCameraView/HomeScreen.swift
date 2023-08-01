import SwiftUI

struct HomeScreen: View {
    @State private var selected: Int = 0

    @State private var resolution: String = "1920x1080"
    @State private var fps: String = "60"
    @State private var format: String = "mp4"
    @State private var codec: String = "hevc"
    @State private var hand: String = "Left"

    
    var body: some View {
        ZStack {
            Color(red: 0.85, green: 0.84, blue: 0.80)
                .edgesIgnoringSafeArea(.all)

            VStack() {

                Spacer()
                NavigationLink(destination: CameraViewHandsWrapper(desiredResolution: $resolution, desiredFPS: $fps, desiredExtension: $format, desiredCodec: $codec, chilarity: hand)
                    .navigationBarBackButtonHidden(true)) {
                    Text("Start Assessment")
                        .font(.custom("montserrat", size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 250, height: 50)
                        .background(Color.black)
                        .cornerRadius(45)
                }
                .padding([.top,.bottom], 60)
                Spacer()
            }
        }
    }
}

