import SwiftUI

struct ElderReminderModalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let reminder: Reminder

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: reminder.date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.black)
                                .font(.title3)
                                .padding(.all, 12)
                                .background(Color(hex: "F2F2F7"))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F2F2F7"))
                            .frame(width: 260, height: 260)
                        
                        if let fileName = ReminderImageReference.fileName(from: reminder.imageName),
                           let image = LocalImageStore.load(fileName: fileName) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 260, height: 260)
                                .clipShape(Circle())
                        } else {
                            Text(reminder.imageName ?? "💊")
                                .font(.system(size: 110))
                        }
                    }
                    .padding(.bottom, 30)
                    
                    VStack(spacing: 8) {
                        Text(reminder.title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text(reminder.notes.isEmpty ? reminder.category.rawValue : reminder.notes)
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                        
                        Text(reminder.repeatOption.rawValue)
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(Color(hex: "007AFF"))
                        Text(timeText)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "007AFF"))
                    }
                    .padding(.bottom, 30)
                    
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await appState.snoozeReminder(reminder)
                                dismiss()
                            }
                        } label: {
                            Text("Snooze 5 mins")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(Color(hex: "007AFF"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(hex: "007AFF"), lineWidth: 1)
                                )
                        }
                        
                        Button {
                            Task {
                                await appState.completeReminder(reminder)
                                dismiss()
                            }
                        } label: {
                            Text("Done")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "007AFF"))
                                .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
