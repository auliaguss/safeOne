import SwiftUI

struct OutgoingCallView: View {
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

                Text("Calling for Help")
                    .font(.system(size: 30, weight: .bold))
                    .padding(.bottom, 48)

                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 200, height: 200)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 160, height: 160)
                    Image(systemName: "phone.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }

                Spacer()

                Text("If this was a mistake,\nplease tap Cancel.")
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)

                Text("Cancel")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.blue)
                    .cornerRadius(14)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    OutgoingCallView()
}
