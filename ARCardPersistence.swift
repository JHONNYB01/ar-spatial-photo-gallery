//
//  ARCardPersistence.swift
//  baby
//
//  Ogni card è legata fisicamente all'ambiente dove è stata posizionata.
//  Il WorldMap (DNA della stanza) viene salvato come file binario
//  nella Documents directory — non in UserDefaults (troppo grande).
//

import ARKit
import simd
import Foundation
import Combine

// MARK: - Modello ambiente salvato

struct SavedEnvironment: Codable {
    let environmentID: String
    let worldMapFilename: String          // file .arworldmap nella Documents dir
    var cardTransforms: [String: [Float]] // cardUUID → 16 float della matrice 4×4
    var createdAt: Date
    var label: String
}

// MARK: - ARCardPersistence

final class ARCardPersistence {
    static let shared = ARCardPersistence()
    private init() {}

    private let indexKey = "ar_environments_index_v3"

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func worldMapURL(filename: String) -> URL {
        documentsURL.appendingPathComponent(filename)
    }

    func anchorName(for card: PhotoCard) -> String {
        "photocard_\(card.id.uuidString)"
    }

    // MARK: - Indice ambienti (UserDefaults, solo metadati leggeri)

    func loadAllEnvironments() -> [SavedEnvironment] {
        guard let data = UserDefaults.standard.data(forKey: indexKey),
              let envs = try? JSONDecoder().decode([SavedEnvironment].self, from: data)
        else { return [] }
        return envs
    }

    private func saveIndex(_ envs: [SavedEnvironment]) {
        guard let data = try? JSONEncoder().encode(envs) else { return }
        UserDefaults.standard.set(data, forKey: indexKey)
    }

    // MARK: - WorldMap su file

    func loadWorldMap(for env: SavedEnvironment) -> ARWorldMap? {
        guard let data = try? Data(contentsOf: worldMapURL(filename: env.worldMapFilename)),
              let map  = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
        else { return nil }
        return map
    }

    // MARK: - Match ambiente

    /// Confronta il WorldMap live con tutti quelli salvati su disco.
    /// Restituisce il miglior match se supera la soglia.
    func matchEnvironment(currentMap: ARWorldMap, threshold: Int = 6) -> SavedEnvironment? {
        let envs = loadAllEnvironments()
        guard !envs.isEmpty else { return nil }

        let currentIDs = Set(currentMap.anchors.map { $0.name ?? $0.identifier.uuidString })

        var bestEnv: SavedEnvironment?
        var bestScore = 0

        for env in envs {
            guard let savedMap = loadWorldMap(for: env) else { continue }
            let savedIDs = Set(savedMap.anchors.map { $0.name ?? $0.identifier.uuidString })
            let score    = currentIDs.intersection(savedIDs).count
            if score > bestScore { bestScore = score; bestEnv = env }
        }

        return bestScore >= threshold ? bestEnv : nil
    }

    // MARK: - Salva card + WorldMap

    @discardableResult
    func saveCardTransform(
        _ transform: simd_float4x4,
        for card: PhotoCard,
        worldMap: ARWorldMap,
        inEnvironmentID existingID: String? = nil
    ) -> String {
        var envs = loadAllEnvironments()

        guard let mapData = try? NSKeyedArchiver.archivedData(
            withRootObject: worldMap, requiringSecureCoding: true
        ) else { return existingID ?? UUID().uuidString }

        if let existingID, let idx = envs.firstIndex(where: { $0.environmentID == existingID }) {
            try? mapData.write(to: worldMapURL(filename: envs[idx].worldMapFilename), options: .atomic)
            envs[idx].cardTransforms[card.id.uuidString] = encoded(transform)
            saveIndex(envs)
            return existingID
        } else {
            let newID    = UUID().uuidString
            let filename = "env_\(newID).arworldmap"
            try? mapData.write(to: worldMapURL(filename: filename), options: .atomic)
            let newEnv = SavedEnvironment(
                environmentID:    newID,
                worldMapFilename: filename,
                cardTransforms:   [card.id.uuidString: encoded(transform)],
                createdAt:        Date(),
                label:            "Ambiente \(envs.count + 1)"
            )
            envs.append(newEnv)
            saveIndex(envs)
            return newID
        }
    }

    func cardTransforms(for env: SavedEnvironment) -> [String: simd_float4x4] {
        env.cardTransforms.compactMapValues { decoded($0) }
    }

    // MARK: - Rimozione

    func removeCard(_ card: PhotoCard, from environmentID: String) {
        var envs = loadAllEnvironments()
        guard let idx = envs.firstIndex(where: { $0.environmentID == environmentID }) else { return }
        envs[idx].cardTransforms.removeValue(forKey: card.id.uuidString)
        if envs[idx].cardTransforms.isEmpty {
            try? FileManager.default.removeItem(at: worldMapURL(filename: envs[idx].worldMapFilename))
            envs.remove(at: idx)
        }
        saveIndex(envs)
    }

    func clearAllData() {
        for env in loadAllEnvironments() {
            try? FileManager.default.removeItem(at: worldMapURL(filename: env.worldMapFilename))
        }
        UserDefaults.standard.removeObject(forKey: indexKey)
    }

    // MARK: - Encode / Decode

    private func encoded(_ t: simd_float4x4) -> [Float] {
        [t.columns.0.x, t.columns.0.y, t.columns.0.z, t.columns.0.w,
         t.columns.1.x, t.columns.1.y, t.columns.1.z, t.columns.1.w,
         t.columns.2.x, t.columns.2.y, t.columns.2.z, t.columns.2.w,
         t.columns.3.x, t.columns.3.y, t.columns.3.z, t.columns.3.w]
    }

    private func decoded(_ f: [Float]) -> simd_float4x4? {
        guard f.count == 16 else { return nil }
        return simd_float4x4(columns: (
            SIMD4(f[0],  f[1],  f[2],  f[3]),  SIMD4(f[4],  f[5],  f[6],  f[7]),
            SIMD4(f[8],  f[9],  f[10], f[11]), SIMD4(f[12], f[13], f[14], f[15])
        ))
    }
}
