import SwiftUI

struct IncomingCallView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 16, weight: .medium))
                        .padding(.trailing, 24)
                        .padding(.top, 8)
                }

                Spacer()

                VStack(spacing: 6) {
                    Text("Emergency Call")
                        .font(.system(size: 28, weight: .bold))
                    Text("Sukarni")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }

                Spacer().frame(height: 48)

                ZStack {
                    Circle()
                        .fill(Color(red: 0.87, green: 0.95, blue: 1.0))
                        .frame(width: 200, height: 200)
                    Image("avatar_elder")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                }

                Spacer()

                HStack(spacing: 40) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.red)
                        .clipShape(Circle())

                    Image(systemName: "phone.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .padding(.bottom, 60)
            }
        }
    }
}

#Preview {
    IncomingCallView()
}
