import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var model = StitchViewModel()
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    hero

                    PhotosPicker(
                        selection: $model.pickerItems,
                        maxSelectionCount: 20,
                        selectionBehavior: .ordered,
                        matching: .images
                    ) {
                        Label(model.sourceImages.isEmpty ? "Choose Screenshots" : "Choose Different Screenshots",
                              systemImage: "photo.stack")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .onChange(of: model.pickerItems) { _, _ in
                        Task { await model.loadSelectedImages() }
                    }

                    if !model.sourceImages.isEmpty {
                        selectedStrip
                    }

                    if model.sourceImages.count >= 2 && model.stitchedImage == nil {
                        Button {
                            Task { await model.stitch() }
                        } label: {
                            Label("Create Long Screenshot", systemImage: "wand.and.stars")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isWorking)
                    }

                    if model.isWorking {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text(model.progressText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }

                    if let image = model.stitchedImage {
                        resultCard(image)
                    }

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if let saved = model.saveMessage {
                        Label(saved, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding()
            }
            .navigationTitle("LongShot")
            .sheet(isPresented: $showingShare) {
                if let image = model.stitchedImage {
                    ShareSheet(items: [image])
                }
            }
            .toolbar {
                if !model.sourceImages.isEmpty {
                    Button("Reset") { model.reset() }
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
            Text("Turn several screenshots into one continuous image.")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("Take screenshots with some overlap as you scroll. Select them in order and LongShot removes the duplicated sections automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var selectedStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(model.sourceImages.count) selected")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(model.sourceImages.enumerated()), id: \.offset) { index, image in
                        VStack(spacing: 5) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text("\(index + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultCard(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Long screenshot ready", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
            }

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 520)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack {
                Button {
                    model.saveToPhotos()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showingShare = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
