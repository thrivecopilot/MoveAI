//
//  NotesTabView.swift
//  MoveAI
//
//  Notes tab: session notes edit/view.
//

import SwiftUI

struct NotesTabView: View {
    @Binding var notes: String
    @Binding var isEditing: Bool
    let onSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing { onSave() }
                    isEditing.toggle()
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            if isEditing {
                TextField("Add notes about this session...", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
            } else {
                Text(notes.isEmpty ? "No notes added" : notes)
                    .font(.body)
                    .foregroundColor(notes.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#if DEBUG
#Preview("Notes tab") {
    NotesTabView(
        notes: .constant("Preview notes for this session."),
        isEditing: .constant(false),
        onSave: {}
    )
}

#Preview("Notes tab (editing)") {
    NotesTabView(
        notes: .constant(""),
        isEditing: .constant(true),
        onSave: {}
    )
}
#endif
