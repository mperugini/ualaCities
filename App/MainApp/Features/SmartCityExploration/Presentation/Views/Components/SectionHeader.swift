//
//  SectionHeader.swift
//  SmartCityExploration
//
//  Created by Mariano Perugini on 15/09/2025.
//
import SwiftUI

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}
