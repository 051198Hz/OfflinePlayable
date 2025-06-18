//
//  FileImportView.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/11/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileImportView: View {
    var allowedTypes: [UTType]
    var title: String
    var onPick: ([URL]) -> Void

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label(title, systemImage: "plus")
        }
        .fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
//                _ = url.startAccessingSecurityScopedResource()
                onPick(urls)
//                url.stopAccessingSecurityScopedResource()
            case .failure(let error):
                print("파일 선택 실패: \(error.localizedDescription)")
            }
        }
    }
}
