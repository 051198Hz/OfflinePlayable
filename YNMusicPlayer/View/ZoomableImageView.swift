//
//  ZoomableScrollView.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/16/25.
import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator(image: image)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false

        // ImageView
        let imageView = ContextmenuableImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(imageView)

        // 더블탭 제스처
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)

        // 컨텍스트 메뉴
        let interaction = UIContextMenuInteraction(delegate: imageView)
        imageView.addInteraction(interaction)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // No update needed
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        let image: UIImage
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?

        init(image: UIImage) {
            self.image = image
        }

        // 줌 대상
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        // 줌 후 중앙정렬
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            let scrollSize = scrollView.bounds.size
            let imageSize = imageView.frame.size

            let hInset = max(0, (scrollSize.width - imageSize.width) / 2)
            let vInset = max(0, (scrollSize.height - imageSize.height) / 2)

            scrollView.contentInset = UIEdgeInsets(top: vInset, left: hInset, bottom: vInset, right: hInset)
        }

        // 더블탭 줌
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            if scrollView.zoomScale > 1.0 {
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let zoomRect = zoomRectFor(scale: 2.5, center: point, in: scrollView)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        private func zoomRectFor(scale: CGFloat, center: CGPoint, in scrollView: UIScrollView) -> CGRect {
            let size = scrollView.bounds.size
            let width = size.width / scale
            let height = size.height / scale
            let origin = CGPoint(x: center.x - width / 2, y: center.y - height / 2)
            return CGRect(origin: origin, size: CGSize(width: width, height: height))
        }
    }
}

class ContextmenuableImageView: UIImageView, UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let image = self.image else { return nil }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            let controller = UIViewController()
            controller.view.backgroundColor = .clear

            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.backgroundColor = .clear
            imageView.translatesAutoresizingMaskIntoConstraints = false

            controller.view.addSubview(imageView)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
                imageView.topAnchor.constraint(equalTo: controller.view.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)
            ])

            controller.preferredContentSize = CGSize(width: image.size.width / image.scale,
                                                     height: image.size.height / image.scale)

            return controller
        }) { _ in
            let copy = UIAction(title: "복사", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.image = image
            }
            let share = UIAction(title: "공유", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.topMostViewController.present(activityVC, animated: true)
                }
            }
            return UIMenu(title: "", children: [copy, share])
        }
    }
}


struct ImageZoomSheet: View {
    let image: UIImage

    var body: some View {
        ZoomableImageView(image: image)
            .ignoresSafeArea(.all) // <- SafeArea 완전 무시
            .background(Color.black)
    }
}

extension UIViewController {
    var topMostViewController: UIViewController {
        presentedViewController?.topMostViewController ?? self
    }
}

// utility extension to easily get the window
public extension UIApplication {
    func currentUIWindow() -> UIWindow? {
        let connectedScenes = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
        
        let window = connectedScenes.first?
            .windows
            .first { $0.isKeyWindow }

        return window
        
    }
}
