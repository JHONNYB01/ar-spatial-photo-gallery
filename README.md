# AR Spatial Photo Gallery

> An iOS Augmented Reality gallery: your photos become **procedurally-built 3D "polaroids"**,
> physically anchored to the room and **persisted across sessions** via `ARWorldMap`.

Built during my time at the **Apple Developer Academy**.

---

## What it demonstrates

| Area | Skill shown |
|------|-------------|
| **RealityKit (procedural 3D)** | Building entities from scratch: boxes, planes, PBR + unlit materials, 3D extruded text, drop shadow |
| **Texture pipeline** | `UIImage` -> normalize/downscale -> `CGImage` -> `TextureResource` (async) |
| **Spatial persistence** | Saving/loading `ARWorldMap` to disk; multi-environment index |
| **Environment matching** | Scoring the live world map against saved ones by shared anchors |
| **Math** | Encoding/decoding `simd_float4x4` transforms (4x4 matrix <-> [Float]) |
| **Architecture** | Singletons, `Codable` models, `Documents` vs `UserDefaults` split |

---

## Highlight 1 - Procedural polaroid (`PolaroidBuilder.swift`)

A polaroid is generated entirely in code - no 3D asset files. White body, two photo planes
(front/back), 3D text labels and a soft shadow, then lifted by half its thickness before
rotating so it rests flush on the detected surface:

```swift
var whiteMat = PhysicallyBasedMaterial()
whiteMat.baseColor = .init(tint: .white)
whiteMat.roughness = .init(floatLiteral: 0.95)
let body = ModelEntity(
    mesh: .generateBox(width: cardW, height: cardH, depth: cardD, cornerRadius: 0.003),
    materials: [whiteMat]
)
```

---

## Highlight 2 - Spatial persistence (`ARCardPersistence.swift`)

Each card is tied to the physical room where it was placed. The `ARWorldMap` (the "DNA" of the
room) is archived to the Documents directory, while a lightweight index lives in `UserDefaults`.
On launch the app matches the live world map against saved ones by counting shared anchors:

```swift
func matchEnvironment(currentMap: ARWorldMap, threshold: Int = 6) -> SavedEnvironment? {
    let currentIDs = Set(currentMap.anchors.map { $0.name ?? $0.identifier.uuidString })
    // ... pick the saved environment with the most overlapping anchors
}
```

---

## What's in this repo

A **portfolio excerpt** - two of the most interesting files, not the full app:

- [`PolaroidBuilder.swift`](PolaroidBuilder.swift) - procedural 3D polaroid generation in RealityKit.
- [`ARCardPersistence.swift`](ARCardPersistence.swift) - `ARWorldMap` persistence + environment matching.

The UI (SwiftUI views, camera capture, gallery navigation) is intentionally omitted.

---

*Built with Swift, RealityKit, ARKit - Apple Developer Academy project.*
