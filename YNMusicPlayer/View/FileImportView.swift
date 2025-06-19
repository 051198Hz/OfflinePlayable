//
//  FileImportView.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/11/25.
//

import SwiftUI
import UniformTypeIdentifiers
import OSLog

struct FileImportView: View {
    var allowedTypes: [UTType]
    var title: String
    var onPick: ([URL]) -> Void

    private let logger = Logger()
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
                guard urls.map({ $0.startAccessingSecurityScopedResource() }).filter({ $0 == false }).isEmpty else { return }
                onPick(urls)
                urls.forEach { $0.stopAccessingSecurityScopedResource() }
            case .failure(let error):
                logger.debug("🔴 파일 선택 실패: \(error.localizedDescription)")
            }
        }
    }
}
