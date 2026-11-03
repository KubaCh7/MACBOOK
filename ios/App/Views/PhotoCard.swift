import PhotosUI
import SwiftUI
import UIKit

/// Zdjęcie celu w proporcji 4:3 (całe, nie ucięte przez układ). Bez zdjęcia: spokojna ikona
/// z napisem „Dodaj zdjęcie” — dotknięcie od razu otwiera galerię. Kadr przesuwa się palcem.
struct PhotoCard: View {
    @EnvironmentObject var store: AppStore
    let goal: GoalEntity

    @State private var item: PhotosPickerItem?
    @State private var editing = false
    @State private var pos = PhotoPosition()
    @State private var dragStart: PhotoPosition?
    @State private var showCamera = false
    @State private var showLink = false
    @State private var link = ""
    @State private var error: String?

    private var image: UIImage? { goal.photoData.flatMap { UIImage(data: $0) } }

    var body: some View {
        VStack(spacing: 10) {
            if let image {
                GeometryReader { geo in
                    PositionedImage(image: image, position: pos)
                        .gesture(drag(image: image, frame: geo.size), including: editing ? .all : .none)
                }
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(editing ? Theme.text : Color.clear, lineWidth: 2)
                )
                .overlay(alignment: .bottomTrailing) {
                    if editing {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(7)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 6))
                            .padding(8)
                    }
                }
                .accessibilityLabel(goal.name)
            } else {
                PhotosPicker(selection: $item, matching: .images) {
                    VStack(spacing: 10) {
                        Image("Laptop").renderingMode(.template).resizable().scaledToFit().frame(width: 36, height: 36)
                        Text(L.t("addPhoto")).font(.system(size: 15, weight: .medium)).lineLimit(1)
                    }
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                if image != nil {
                    Button(editing ? L.t("done") : L.t("adjustCrop")) {
                        if editing { store.setPhotoPosition(goal, pos) }
                        editing.toggle()
                        Sound.shared.click()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Menu {
                    PhotosPicker(selection: $item, matching: .images) { Label(L.t("fromGallery"), systemImage: "photo") }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: { Label(L.t("fromCamera"), systemImage: "camera") }
                    }
                    Button { showLink = true } label: { Label(L.t("fromLink"), systemImage: "link") }
                    if image != nil {
                        Button(role: .destructive) {
                            editing = false
                            store.setPhoto(goal, data: nil)
                        } label: { Label(L.t("removePhoto"), systemImage: "trash") }
                    }
                } label: {
                    SecondaryLabel(text: image == nil ? L.t("addPhoto") : L.t("changePhoto"))
                }
            }
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.negative)
            }
        }
        .onAppear { pos = PhotoPosition(string: goal.photoPosition) }
        .onChange(of: goal.photoPosition) { _, v in if !editing { pos = PhotoPosition(string: v) } }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task {
                let loaded = try? await newItem.loadTransferable(type: Data.self)
                if let data = loaded ?? nil {
                    store.setPhoto(goal, data: data)
                    pos = PhotoPosition()
                }
                item = nil
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { data in
                store.setPhoto(goal, data: data)
                pos = PhotoPosition()
            }
            .ignoresSafeArea()
        }
        .alert(L.t("fromLink"), isPresented: $showLink) {
            TextField("https://…", text: $link)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
            Button(L.t("cancel"), role: .cancel) { link = "" }
            Button(L.t("use")) { loadLink() }
        }
    }

    private func drag(image: UIImage, frame: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                let start = dragStart ?? pos
                if dragStart == nil { dragStart = pos }
                let scale = max(frame.width / max(image.size.width, 1), frame.height / max(image.size.height, 1))
                let overflowX = image.size.width * scale - frame.width
                let overflowY = image.size.height * scale - frame.height
                let nx = overflowX > 1 ? start.x - Double(v.translation.width / overflowX) * 100 : start.x
                let ny = overflowY > 1 ? start.y - Double(v.translation.height / overflowY) * 100 : start.y
                pos = PhotoPosition(x: nx, y: ny)
            }
            .onEnded { _ in
                dragStart = nil
                store.setPhotoPosition(goal, pos)
            }
    }

    private func loadLink() {
        let u = link.trimmingCharacters(in: .whitespaces)
        link = ""
        guard u.lowercased().hasPrefix("https://"), let url = URL(string: u) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard UIImage(data: data) != nil else { throw URLError(.cannotDecodeContentData) }
                store.setPhoto(goal, data: data, link: u)
                pos = PhotoPosition()
                error = nil
            } catch {
                self.error = L.t("error", ["msg": error.localizedDescription])
            }
        }
    }
}

/// Aparat (UIImagePickerController).
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage, let data = img.jpegData(compressionQuality: 0.9) {
                parent.onImage(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
