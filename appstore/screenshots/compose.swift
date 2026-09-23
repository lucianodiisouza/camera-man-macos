// Lays out the Mac App Store screenshots (1440×900) from the raw window captures in raw/ and a portrait for the
// camera bubble.
//
// Run from the repo root:
//     swift appstore/screenshots/compose.swift
//
// Reads  appstore/screenshots/raw/<lang>-<page>.png  and  appstore/screenshots/portrait.jpg (optional; a silhouette
// is drawn without it). Writes appstore/screenshots/<lang>/<n>-<name>.png.

import AppKit
import SwiftUI

let root = URL(fileURLWithPath: "appstore/screenshots")
let size = CGSize(width: 1440, height: 900)

// MARK: - Pieces

private let red = Color(red: 1.0, green: 0.23, blue: 0.23)

/// The same organic outline the app draws (Wave preset).
struct Blob: Shape {
    func path(in rect: CGRect) -> Path {
        let waves: [(k: Double, a: Double, p: Double)] = [(2, 0.035, 1.0), (4, 0.022, 0.2), (5, 0.01, 2.4)]
        let n = 240
        let radii = (0..<n).map { i -> Double in
            let t = 2 * .pi * Double(i) / Double(n)
            return waves.reduce(1) { $0 + $1.a * cos($1.k * t + $1.p) }
        }
        let s = min(rect.width, rect.height) / 2 / radii.max()!
        var path = Path()
        for (i, r) in radii.enumerated() {
            let t = 2 * .pi * Double(i) / Double(n)
            let pt = CGPoint(x: rect.midX + r * s * cos(t), y: rect.midY + r * s * sin(t))
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}

struct Portrait: View {
    let image: NSImage?
    var body: some View {
        if let image {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(colors: [Color(red: 0.42, green: 0.47, blue: 0.55), Color(red: 0.2, green: 0.25, blue: 0.33)], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .bottom) {
                    Image(systemName: "person.fill").resizable().scaledToFit().foregroundStyle(.white.opacity(0.9)).padding(.horizontal, 20).offset(y: 20)
                }
        }
    }
}

enum BubbleStyle { case organicGradient, softCircle, circle }

struct Bubble: View {
    let image: NSImage?
    let diameter: CGFloat
    var style: BubbleStyle = .organicGradient

    var body: some View {
        let gradient = LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.66, green: 0.33, blue: 0.97)], startPoint: .topLeading, endPoint: .bottomTrailing)
        switch style {
        case .organicGradient:
            Portrait(image: image)
                .frame(width: diameter, height: diameter)
                .clipShape(Blob())
                .overlay(Blob().stroke(gradient, lineWidth: diameter * 0.022))
                .shadow(color: .black.opacity(0.45), radius: diameter * 0.05, y: diameter * 0.02)
        case .softCircle:
            Portrait(image: image)
                .frame(width: diameter, height: diameter)
                .mask(Circle().padding(diameter * 0.04).blur(radius: diameter * 0.04))
        case .circle:
            Portrait(image: image)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.45), radius: diameter * 0.05, y: diameter * 0.02)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.07, blue: 0.09), Color(red: 0.13, green: 0.07, blue: 0.09)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [red.opacity(0.22), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 900)
        }
    }
}

struct Headline: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(.system(size: 50, weight: .bold)).foregroundStyle(.white)
            Text(subtitle).font(.system(size: 22, weight: .medium)).foregroundStyle(.white.opacity(0.65))
        }
        .multilineTextAlignment(.center)
    }
}

/// A made-up slide, standing in for whatever the creator is presenting.
struct SlideMock: View {
    let lang: String
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.97, green: 0.96, blue: 0.94))
            VStack(alignment: .leading, spacing: 22) {
                Text(lang == "pt-BR" ? "Resultados do trimestre" : "Quarterly results")
                    .font(.system(size: 40, weight: .bold)).foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.16))
                HStack(alignment: .bottom, spacing: 26) {
                    ForEach(Array([0.35, 0.5, 0.45, 0.7, 0.62, 0.9].enumerated()), id: \.offset) { i, v in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(i == 5 ? red : Color(red: 0.25, green: 0.3, blue: 0.4))
                            .frame(width: 60, height: 300 * v)
                    }
                }
                .frame(height: 300, alignment: .bottom)
                ForEach(0..<2) { i in
                    RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.12)).frame(width: i == 0 ? 520 : 380, height: 16)
                }
            }
            .padding(56)
        }
    }
}

struct Window: View {
    let image: NSImage
    var body: some View {
        Image(nsImage: image)
            .interpolation(.high)
            .frame(width: image.size.width, height: image.size.height)
            .shadow(color: .black.opacity(0.55), radius: 30, y: 16)
    }
}

// MARK: - Screens

struct Hero: View {
    let lang: String, portrait: NSImage?
    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 34) {
                Headline(
                    title: lang == "pt-BR" ? "Apareça na tela" : "Put yourself on screen",
                    subtitle: lang == "pt-BR" ? "Uma câmera flutuante para gravações, demos e aulas" : "A floating camera for recordings, demos and classes")
                SlideMock(lang: lang).frame(width: 1060, height: 600)
            }
            .padding(.top, 60)
            .frame(maxHeight: .infinity, alignment: .top)
            Bubble(image: portrait, diameter: 330).position(x: 1150, y: 690)
        }
    }
}

struct WindowScreen: View {
    let title: String, subtitle: String, window: NSImage, portrait: NSImage?, style: BubbleStyle
    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 40) {
                Headline(title: title, subtitle: subtitle)
                Window(image: window)
            }
            .padding(.top, 58)
            .frame(maxHeight: .infinity, alignment: .top)
            Bubble(image: portrait, diameter: 260, style: style).position(x: 1215, y: 690)
        }
    }
}

// MARK: - Render

@MainActor
func write<V: View>(_ view: V, to url: URL) throws {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 1
    guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
    // Flattened onto an opaque sRGB canvas: App Store Connect rejects screenshots with an alpha channel.
    guard let context = CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw CocoaError(.fileWriteUnknown) }
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let flat = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: flat).representation(using: .png, properties: [:])
    else { throw CocoaError(.fileWriteUnknown) }
    try png.write(to: url)
}

let portrait = NSImage(contentsOf: root.appendingPathComponent("portrait.jpg"))
print(portrait == nil ? "(no portrait.jpg — drawing a silhouette)" : "using portrait.jpg")

let copy: [String: [(page: String, title: String, subtitle: String, style: BubbleStyle)]] = [
    "en": [
        ("shape", "Shapes that feel natural", "Circle, organic and more — with a soft edge if you like", .softCircle),
        ("border", "Make it yours", "Borders, gradients and soft shadows", .organicGradient),
        ("shortcuts", "Control it from any app", "Show, hide and resize without leaving your recording", .circle),
        ("framing", "Frame yourself just right", "Position, zoom and color, applied live", .organicGradient),
    ],
    "pt-BR": [
        ("shape", "Formatos que parecem naturais", "Círculo, orgânico e mais — com borda suave se quiser", .softCircle),
        ("border", "Do seu jeito", "Bordas, gradientes e sombras suaves", .organicGradient),
        ("shortcuts", "Controle de qualquer app", "Mostre, oculte e redimensione sem sair da gravação", .circle),
        ("framing", "Enquadre-se do jeito certo", "Posição, zoom e cor, aplicados ao vivo", .organicGradient),
    ],
]

MainActor.assumeIsolated {
    do {
        for (lang, screens) in copy {
            let dir = root.appendingPathComponent(lang)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try write(Hero(lang: lang, portrait: portrait), to: dir.appendingPathComponent("1-hero.png"))
            for (i, s) in screens.enumerated() {
                guard let window = NSImage(contentsOf: root.appendingPathComponent("raw/\(lang)-\(s.page).png")) else {
                    print("missing raw/\(lang)-\(s.page).png"); continue
                }
                try write(
                    WindowScreen(title: s.title, subtitle: s.subtitle, window: window, portrait: portrait, style: s.style),
                    to: dir.appendingPathComponent("\(i + 2)-\(s.page).png"))
            }
            print("✓ \(lang)")
        }
    } catch {
        print("✗ \(error)")
        exit(1)
    }
}
