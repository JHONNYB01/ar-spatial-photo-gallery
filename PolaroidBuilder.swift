//
//  PolaroidBuilder.swift
//  baby
//
//  Created by Gennaro Biagino on 02/04/2026.
//
import RealityKit
import UIKit
import ARKit

@MainActor
func buildPolaroid(for card: PhotoCard) async -> Entity {
    let root = Entity()

    let cardW: Float = 0.12
    let cardD: Float = 0.14
    let cardH: Float = 0.003
    let marginSide: Float  = 0.007
    let marginTop: Float   = 0.006
    let bottomStrip: Float = 0.028

    let photoW: Float = cardW - (marginSide * 2)
    let photoD: Float = cardD - marginTop - bottomStrip
    let photoCenterZ: Float = (marginTop - bottomStrip) / 2

    // ── 1. Corpo bianco polaroid ──
    var whiteMat = PhysicallyBasedMaterial()
    whiteMat.baseColor = .init(tint: .white)
    whiteMat.roughness  = .init(floatLiteral: 0.95)
    whiteMat.metallic   = .init(floatLiteral: 0.0)
    root.addChild(ModelEntity(
        mesh: MeshResource.generateBox(
            width: cardW, height: cardH, depth: cardD, cornerRadius: 0.003
        ),
        materials: [whiteMat]
    ))

    // ── 2. Prepara le due texture ──
    let textureTop    = await loadTexture(from: card.image, rotate180: true)
    let textureBottom = await loadTexture(from: card.image, rotate180: true)

    let photoMesh = MeshResource.generatePlane(
        width: photoW, depth: photoD, cornerRadius: 0.001
    )

    // ── 3. Piano SUPERIORE (+Y) ──
    var matTop = SimpleMaterial()
    matTop.color = textureTop != nil
        ? .init(texture: .init(textureTop!))
        : .init(tint: UIColor(red: 0.75, green: 0.82, blue: 0.90, alpha: 1))
    matTop.roughness = .init(floatLiteral: 0.5)
    matTop.metallic  = .init(floatLiteral: 0.0)

    let topPlane = ModelEntity(mesh: photoMesh, materials: [matTop])
    topPlane.position = SIMD3(0, (cardH / 2) + 0.0003, photoCenterZ)
    root.addChild(topPlane)

    // ── 4. Piano INFERIORE (-Y) ──
    var matBottom = SimpleMaterial()
    matBottom.color = textureBottom != nil
        ? .init(texture: .init(textureBottom!))
        : .init(tint: UIColor(red: 0.75, green: 0.82, blue: 0.90, alpha: 1))
    matBottom.roughness = .init(floatLiteral: 0.5)
    matBottom.metallic  = .init(floatLiteral: 0.0)

    let bottomPlane = ModelEntity(mesh: photoMesh, materials: [matBottom])
    bottomPlane.position = SIMD3(0, -((cardH / 2) + 0.0003), photoCenterZ)
    bottomPlane.transform.rotation = simd_quatf(angle: .pi, axis: SIMD3(0, 0, 1))
    root.addChild(bottomPlane)

    // ── 5. Testo LATO SUPERIORE ──
    addTextLabel(to: root, title: card.title,
                 photoW: photoW, cardH: cardH, cardD: cardD,
                 bottomStrip: bottomStrip, ySign: 1.0)

    // ── 6. Testo LATO INFERIORE ──
    addTextLabel(to: root, title: card.title,
                 photoW: photoW, cardH: cardH, cardD: cardD,
                 bottomStrip: bottomStrip, ySign: -1.0)

    // ── 7. Ombra ──
    var shadowMat = SimpleMaterial()
    shadowMat.color = .init(tint: UIColor(red: 0, green: 0, blue: 0, alpha: 0.18))
    let shadow = ModelEntity(
        mesh: MeshResource.generateBox(
            width: cardW + 0.004, height: 0.0001,
            depth: cardD + 0.004, cornerRadius: 0.003
        ),
        materials: [shadowMat]
    )
    shadow.position = SIMD3(0.002, -(cardH / 2) - 0.001, 0.002)
    root.addChild(shadow)

    // ── 8. FIX: alza il root di metà spessore PRIMA di ruotare ──
    // Così il fondo della card tocca la superficie senza sprofondare
    root.transform = Transform(
        scale: .one,
        rotation: simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0)),
        translation: SIMD3(0, cardH / 2 + 0.001, 0)
    )

    return root
}

// MARK: - Carica texture

@MainActor
private func loadTexture(from image: UIImage?, rotate180: Bool) async -> TextureResource? {
    guard let image else { return nil }
    let normalized = image.normalized(maxSize: 1024)
    let finalImage = rotate180 ? normalized.rotated180() : normalized
    guard let cgImage = finalImage.cgImage else { return nil }
    return try? await TextureResource.generate(
        from: cgImage,
        options: TextureResource.CreateOptions(semantic: .color)
    )
}

// MARK: - Testo

private func addTextLabel(
    to root: Entity,
    title: String,
    photoW: Float,
    cardH: Float,
    cardD: Float,
    bottomStrip: Float,
    ySign: Float
) {
    let label = title.isEmpty ? "Card" : title
    var textMat = UnlitMaterial()
    textMat.color = .init(tint: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1))

    let textMesh = MeshResource.generateText(
        label,
        extrusionDepth: 0.00001,
        font: .systemFont(ofSize: 0.0072, weight: .medium),
        containerFrame: CGRect(
            x: -Double(photoW / 2),
            y: -0.006,
            width: Double(photoW),
            height: 0.012
        ),
        alignment: .center,
        lineBreakMode: .byTruncatingTail
    )

    let textEntity = ModelEntity(mesh: textMesh, materials: [textMat])

    let yPos = ySign * ((cardH / 2) + 0.0005)
    let zPos = (cardD / 2) - (bottomStrip / 2)
    textEntity.position = SIMD3(0, yPos, zPos)

    if ySign > 0 {
        textEntity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
    } else {
        textEntity.transform.rotation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
    }
    root.addChild(textEntity)
}

// MARK: - UIImage extensions

extension UIImage {
    func normalized(maxSize: CGFloat = 1024) -> UIImage {
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = scale < 1.0
            ? CGSize(width: size.width * scale, height: size.height * scale)
            : size
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return result
    }

    func rotated180() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return self
        }
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.rotate(by: .pi)
        draw(in: CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        ))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return result
    }
}

