//
//  NotesTabView.swift
//  MoveAI
//
//  Notes tab: session notes edit/view.
//

import SwiftUI

struct NotesTabView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var notes: String
    @Binding var isEditing: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                    .accessibilityIdentifier(AccessibilityID.Notes.header)
                Spacer()
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing { onSave() }
                    withAnimation(CoachTheme.Motion.quick) {
                        isEditing.toggle()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(CoachTheme.Palette.accent)
                .accessibilityIdentifier(AccessibilityID.Notes.editButton)
            }

            if isEditing {
                TextField("Add notes about this session...", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
                    .accessibilityIdentifier(AccessibilityID.Notes.textField)
            } else {
                Text(notes.isEmpty ? "No notes added" : notes)
                    .font(.body)
                    .foregroundColor(notes.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityIdentifier(AccessibilityID.Notes.notesText)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CoachTheme.Palette.surfaceFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier(AccessibilityID.Notes.root)
        .accessibilityElement(children: .contain)
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
