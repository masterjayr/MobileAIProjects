//
//  PhotoPickerView.swift
//  ImageClassificationiOS
//
//  Created by Emmanuel Emmanuel on 13/03/2026.
//
import SwiftUI
import UIKit

struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed for this view
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, dismiss: dismiss)
    }
}

final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    let parent: PhotoPickerView
    let dismiss: DismissAction
    
    init(_ parent: PhotoPickerView, dismiss: DismissAction) {
        self.parent = parent
        self.dismiss = dismiss
    }
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        if let image = info[.originalImage] as? UIImage {
            parent.selectedImage = image
        }
        
        dismiss()
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss()
    }
}

