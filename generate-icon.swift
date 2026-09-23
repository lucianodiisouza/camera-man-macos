#!/usr/bin/env swift
//
// Draws the CameraMan app icon and writes every size macOS asks for, in the look of the DMG background:
// a dark squircle, red viewfinder corners, and the round camera bubble with a REC dot.
//
// Run from the repo root:
//     swift generate-icon.swift
//
// Output: CameraMan/Assets.xcassets/AppIcon.appiconset
//

import AppKit
import SwiftUI

private let red = Color(red: 1.0, green: 0.13, blue: 0.13)

private struct Bracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

private struct Icon: View {
    var body: some View {
        // macOS icons sit on a 1024 canvas with a 824 body, leaving room for the shadow.
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(white: 0.20), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 3))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)

            // Viewfinder corners.
            ForEach(0..<4) { i in
                Bracket()
                    .stroke(red, style: StrokeStyle(lineWidth: 36, lineCap: .round, lineJoin: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(Double(i) * 90))
                    .offset(
                        x: (i == 0 || i == 3) ? -245 : 245,
                        y: (i == 0 || i == 1) ? -245 : 245)
            }

            // The camera bubble: a person in a circle.
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.42, green: 0.47, blue: 0.55), Color(red: 0.20, green: 0.25, blue: 0.33)],
                    startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .bottom) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 300))
                        .foregroundStyle(.white.opacity(0.92))
                        .offset(y: 40)
                }
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 14))
                .frame(width: 400, height: 400)

            // REC dot.
            Circle()
                .fill(red)
                .overlay(Circle().strokeBorder(Color(white: 0.1), lineWidth: 14))
                .frame(width: 120, height: 120)
                .offset(x: 150, y: -150)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
func render(pixels: Int) -> Data {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = CGFloat(pixels) / 1024
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: "CameraMan/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try MainActor.assumeIsolated { render(pixels: points * scale) }.write(to: out.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: out.appendingPathComponent("Contents.json"))
try #"{"info":{"author":"xcode","version":1}}"#.data(using: .utf8)!
    .write(to: out.deletingLastPathComponent().appendingPathComponent("Contents.json"))
print("✓ wrote \(images.count) icons to \(out.path)")
