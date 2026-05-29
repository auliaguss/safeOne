import SwiftUI

struct OngoingCallView: View {
    var isElder: Bool = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Topbar
            ZStack {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(.leading, 16)
                    
                        .onTapGesture {
                            dismiss()
                        }
                    Spacer()
    
                    VStack(spacing: 2) {
                        Text("Emergency Call")
                            .font(.system(size: 17, weight: .semibold))
                        Text("0:30")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(.trailing, 16)
                        .onTapGesture {
                            dismiss()
                        }

                }
            }
            .frame(height: 44)
            .padding(.top, 4)
            .padding(.bottom, 8)

            // Main area
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.933, green: 1.0, blue: 0.988),
                        Color(red: 0.741, green: 0.925, blue: 1.0)
                    ]),
                    startPoint: UnitPoint(x: 0.37, y: 0.02),
                    endPoint: UnitPoint(x: 0.63, y: 0.98)
                )

                Image(isElder ? "avatar_child" : "avatar_elder")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Bottom bar
            HStack {
                Spacer()

                Image(systemName: "phone.down.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.red)
                    .clipShape(Circle())

                if !isElder {
                    Spacer()

                    Text("SOS")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.gray)
                        .clipShape(Circle())
                }

                Spacer()
            }
            .padding(.vertical, 20)
            .background(Color(UIColor.systemGray6))
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview("Child view") {
    OngoingCallView(isElder: false)
}

#Preview("Elder view") {
    OngoingCallView(isElder: true)
}
