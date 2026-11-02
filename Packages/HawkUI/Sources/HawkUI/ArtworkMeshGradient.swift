import SwiftUI

/// Animated kinetic mesh gradient background inspired by album artwork.
public struct ArtworkMeshGradient: View {
    @State private var animate = false

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground
                .ignoresSafeArea()

            // Dynamic kinetic ambient color orbs
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                Circle()
                    .fill(HawkTheme.primaryAccent.opacity(0.35))
                    .frame(width: w * 0.8, height: w * 0.8)
                    .blur(radius: 60)
                    .offset(x: animate ? w * 0.1 : -w * 0.2, y: animate ? h * 0.1 : -h * 0.1)

                Circle()
                    .fill(HawkTheme.secondaryAccent.opacity(0.30))
                    .frame(width: w * 0.7, height: w * 0.7)
                    .blur(radius: 60)
                    .offset(x: animate ? -w * 0.1 : w * 0.2, y: animate ? h * 0.4 : h * 0.2)

                Circle()
                    .fill(Color.indigo.opacity(0.25))
                    .frame(width: w * 0.6, height: w * 0.6)
                    .blur(radius: 50)
                    .offset(x: animate ? w * 0.2 : 0, y: animate ? h * 0.6 : h * 0.5)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    animate.toggle()
                }
            }
        }
    }
}
