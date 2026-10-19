import Foundation
import CryptoKit

struct ConversionRule: Codable {
    var name: String
    var colorIndex: Int32?
    var role: Int32
    var minX: Float?, maxX: Float?, minY: Float?, maxY: Float?
    var minWidth: Float?, maxWidth: Float?, minHeight: Float?, maxHeight: Float?
    var height: Float
    var elevation: Float?
    var pattern: String?
    func native(depth: Float) -> ADRule {
        ADRule(color_index: colorIndex ?? -1, role: role,
               min_x: minX ?? 0, max_x: maxX ?? 1, min_y: minY ?? 0, max_y: maxY ?? 1,
               min_width: minWidth ?? 0, max_width: maxWidth ?? 1,
               min_height: minHeight ?? 0, max_height: maxHeight ?? 1,
               height: height * depth, elevation: elevation ?? 0,
               pattern: pattern.flatMap { UInt64($0, radix: 16) } ?? 0)
    }
}

// Bounded runtime profile instructions. Read-only RAM conditions can override the
// visual rules for a room/state. They never write RAM or drive emulator inputs.
struct ProfileInstruction: Codable {
    var ramOffset: Int
    var mask: UInt8
    var equals: UInt8
    var ruleIndex: Int
    var height: Float?
    var elevation: Float?
}

struct GameProfile: Codable, Identifiable {
    var schemaVersion: Int
    var id, title: String
    var sha256, md5: [String]
    var compatibility, notes, controller, perspective: String
    var backgroundIndex: Int32
    var hudTop, hudBottom: Float
    var sceneRAMOffset: Int32
    var defaultHeight: Float
    var rules: [ConversionRule]
    var program: [ProfileInstruction]?
    var reconstruction: String? = nil

    static let generic = GameProfile(schemaVersion: 1, id: "generic-v1", title: "Unknown cartridge", sha256: [], md5: [],
        compatibility: "generic", notes: "Experimental color segmentation. Objects and depths may be inaccurate; a game-specific profile improves interpretation.",
        controller: "joystick", perspective: "topDown", backgroundIndex: -1, hudTop: 0, hudBottom: 0,
        sceneRAMOffset: -1, defaultHeight: 0.035, rules: [])
    var badge: String {
        switch compatibility {
        case "development": return "TEST ROM · DEVELOPMENT PROFILE"
        case "full": return "FULL 3D PROFILE"
        case "experimental": return "EXPERIMENTAL 3D PROFILE"
        default: return "GENERIC 3D · EXPERIMENTAL"
        }
    }
    func withNative<T>(ram: [UInt8], depth: Float, quality: Int, _ body: (inout ADProfile) -> T) -> T {
        var nativeRules = rules.map { $0.native(depth: depth) }
        for instruction in (program ?? []).prefix(128) where
            ram.indices.contains(instruction.ramOffset) && nativeRules.indices.contains(instruction.ruleIndex) {
            if ram[instruction.ramOffset] & instruction.mask == instruction.equals {
                if let height = instruction.height { nativeRules[instruction.ruleIndex].height = height * depth }
                if let elevation = instruction.elevation { nativeRules[instruction.ruleIndex].elevation = elevation }
            }
        }
        return nativeRules.withUnsafeMutableBufferPointer { buffer in
            var p = ADProfile(hud_top: hudTop, hud_bottom: hudBottom, default_height: defaultHeight * depth,
                background_index: backgroundIndex, side_view: perspective == "sideView" ? 1 : 0,
                max_objects: quality == 0 ? 256 : 1024, max_boxes: quality == 0 ? 6000 : 24000,
                scene_ram_offset: sceneRAMOffset, rule_count: UInt32(buffer.count), rules: UnsafePointer(buffer.baseAddress),
                adapter: reconstruction == "iceHockeyNTSCv1" ? 1 : reconstruction == "adventureNTSCv1" ? 2 : 0)
            return body(&p)
        }
    }
}

struct LibraryGame: Codable, Identifiable {
    var id, md5, title, filename: String
    var importedAt: Date
    var byteCount: Int
}

struct AppSettings: Codable {
    // Optional for migration: older settings files decode without losing preferences.
    var upright: Bool? = nil
    var worldWidth: Float = 0.35
    var rotation: Float = 0
    var tilt: Float = 0
    var depth: Float = 1
    var ambient: Float = 0.7
    var volume: Float = 0.7
    var controlSize: Float = 1
    var controlOpacity: Float = 0.85
    var sensitivity: Float = 1
    var leftHanded = false
    var haptics = true
    var joystickX: Float = 0
    var joystickY: Float = 0
    var fireX: Float = 0
    var fireY: Float = 0
    var difficultyLeftA = false
    var difficultyRightA = false
    var monochrome = false
    var quality = 1
    var controller = "auto"
    var player = 0
    var view = "Free AR"
}

struct SavedGame: Codable {
    var formatVersion = 1
    var romSHA256, coreRevision, profileID: String
    var created: Date
    var emulator: Data
    var controller: String
}

enum DioramaError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

enum Storage {
    static let coreRevision = "7d1361e407e63f29e52892655069e5fb4096e691"
    static var root: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AtariDiorama", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func directory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func md5(_ data: Data) -> String { Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func read<T: Decodable>(_ type: T.Type, name: String) -> T? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    static func write<T: Encodable>(_ value: T, name: String) throws {
        try JSONEncoder().encode(value).write(to: root.appendingPathComponent(name), options: .atomic)
    }
    static func profiles() -> [GameProfile] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "profiles") ?? []
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url), let profile = try? JSONDecoder().decode(GameProfile.self, from: data),
                  profile.schemaVersion == 1, profile.rules.count <= 128,
                  profile.sha256.allSatisfy({ $0.count == 64 }), profile.md5.allSatisfy({ $0.count == 32 }) else { return nil }
            return profile
        }
    }
}
