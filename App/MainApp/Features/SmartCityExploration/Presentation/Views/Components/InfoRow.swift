//
//  InfoRow.swift
//  SmartCityExploration
//
//  Created by Mariano Peruginoi on 15/09/2025.
//
import SwiftUI

struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}
