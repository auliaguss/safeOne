//
//  ReminderModel.swift
//  safeOne
//
//  Created by Fransiskus Risky Gawahi on 29/05/26.
//
import SwiftUI

struct ReminderItem: Identifiable {
    let id = UUID()
    let title: String
    let dosage: String
    let instruction: String
    let time: String
    let statusText: String
    let imageLink: String?
    let imageName: String //using systemName SF Symbols
}
