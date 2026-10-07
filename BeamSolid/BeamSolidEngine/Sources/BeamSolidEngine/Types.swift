/**
 * BeamSolidEngine — Definições de tipos
 * Porte fiel de `src/types.ts` do BeamSolid Pro (web).
 */
import Foundation

public enum SupportType: String, Codable, CaseIterable, Sendable {
    case biapoiada, cantilever, biengastada, continua
}

/// Única norma efetivamente implementada no motor (γa1 = 1,10 e L/350 são da NBR 8800:2008).
public let APPLICABLE_NORM = "NBR 8800:2008"

public struct SteelGrade: Codable, Sendable, Equatable {
    public var name: String
    public var category: String
    public var fy: Double // MPa
    public var fu: Double // MPa
    public var E: Double  // GPa
    public var G: Double  // GPa
    public var nu: Double

    public init(name: String, category: String, fy: Double, fu: Double, E: Double, G: Double, nu: Double) {
        self.name = name; self.category = category; self.fy = fy; self.fu = fu
        self.E = E; self.G = G; self.nu = nu
    }
}

public struct SteelProfile: Codable, Sendable, Equatable {
    public var id: String
    public var designation: String
    public var family: String
    public var typeDescription: String
    public var massLinear: Double        // kg/m
    public var depth_d: Double           // mm
    public var flangeWidth_bf: Double    // mm
    public var webThickness_tw: Double   // mm
    public var flangeThickness_tf: Double // mm
    public var area_A: Double            // cm²
    public var inertia_Ix: Double        // cm⁴
    public var inertia_Iy: Double        // cm⁴
    public var elasticModulus_Wx: Double // cm³
    public var plasticModulus_Zx: Double // cm³
    public var radiusGyration_rx: Double // cm
    public var radiusGyration_ry: Double // cm
    public var webCompact: Bool
    public var flangeCompact: Bool
    public var tag: String?
    public var savingsVsW250: String?

    public init(
        id: String, designation: String, family: String, typeDescription: String,
        massLinear: Double, depth_d: Double, flangeWidth_bf: Double, webThickness_tw: Double,
        flangeThickness_tf: Double, area_A: Double, inertia_Ix: Double, inertia_Iy: Double,
        elasticModulus_Wx: Double, plasticModulus_Zx: Double, radiusGyration_rx: Double,
        radiusGyration_ry: Double, webCompact: Bool, flangeCompact: Bool,
        tag: String? = nil, savingsVsW250: String? = nil
    ) {
        self.id = id; self.designation = designation; self.family = family
        self.typeDescription = typeDescription; self.massLinear = massLinear
        self.depth_d = depth_d; self.flangeWidth_bf = flangeWidth_bf
        self.webThickness_tw = webThickness_tw; self.flangeThickness_tf = flangeThickness_tf
        self.area_A = area_A; self.inertia_Ix = inertia_Ix; self.inertia_Iy = inertia_Iy
        self.elasticModulus_Wx = elasticModulus_Wx; self.plasticModulus_Zx = plasticModulus_Zx
        self.radiusGyration_rx = radiusGyration_rx; self.radiusGyration_ry = radiusGyration_ry
        self.webCompact = webCompact; self.flangeCompact = flangeCompact
        self.tag = tag; self.savingsVsW250 = savingsVsW250
    }
}

public enum LoadType: String, Codable, Sendable {
    case distributed, point, moment
}

public enum LoadDirection: String, Codable, Sendable {
    case up = "+Y"
    case down = "-Y"
}

public struct SupportPositions: Sendable {
    public var posA: Double
    public var posB: Double
    public var posC: Double?

    public init(posA: Double, posB: Double, posC: Double? = nil) {
        self.posA = posA; self.posB = posB; self.posC = posC
    }
}

public struct LoadItem: Sendable {
    public var id: String
    public var type: LoadType
    public var name: String
    public var value: Double       // kN/m, kN ou kN·m conforme o tipo
    public var positionX: Double   // m
    public var length: Double?     // m (apenas para cargas distribuídas)
    public var direction: LoadDirection
    public var gammaF: Double      // coeficiente de majoração (ex.: 1,25 / 1,40 / 1,50)

    public init(
        id: String = UUID().uuidString, type: LoadType, name: String = "",
        value: Double, positionX: Double, length: Double? = nil,
        direction: LoadDirection = .down, gammaF: Double = 1.4
    ) {
        self.id = id; self.type = type; self.name = name; self.value = value
        self.positionX = positionX; self.length = length
        self.direction = direction; self.gammaF = gammaF
    }
}

public enum CalcStatus: String, Sendable {
    case pass = "PASS"
    case alert = "ALERT"
    case fail = "FAIL"
    case none = "NONE"
    case invalid = "INVALID" // entrada inválida ou falha de integridade (fail-closed)
}

public struct ShearPoint: Sendable { public var x: Double; public var v: Double }
public struct MomentPoint: Sendable { public var x: Double; public var m: Double }
public struct DeflectionPoint: Sendable { public var x: Double; public var d: Double }
public struct VonMisesPoint: Sendable {
    public var x: Double; public var vm: Double; public var sigma: Double; public var tau: Double
}

public struct CalculationResults: Sendable {
    public var reactionA: Double = 0           // kN
    public var reactionB: Double = 0           // kN
    public var reactionC: Double? = nil        // kN (viga contínua)
    public var totalVerticalLoad: Double = 0   // kN
    public var maxMoment: Double = 0           // kN·m
    public var maxMomentX: Double = 0          // m
    public var maxShearPos: Double = 0         // kN
    public var maxShearNeg: Double = 0         // kN
    public var shearZeroX: Double = 0          // m
    public var maxDeflection: Double = 0       // mm
    public var maxDeflectionX: Double = 0      // m
    public var allowableDeflection: Double = 0 // mm
    public var deflectionRatio: Double = 0     // %
    public var momentCapacity_Mrd: Double = 0  // kN·m
    public var shearCapacity_Vrd: Double = 0   // kN
    public var momentRatio: Double = 0         // %
    public var shearRatio: Double = 0          // %
    public var normalStressMax: Double = 0     // MPa
    public var normalStressMaxX: Double = 0    // m
    public var shearStressMax: Double = 0      // MPa
    public var shearStressMaxX: Double = 0     // m
    public var vonMisesMax: Double = 0         // MPa
    public var vonMisesMaxX: Double = 0        // m
    public var allowableStress_fyd: Double = 0 // MPa
    public var vonMisesRatio: Double = 0       // %
    public var status: CalcStatus = .none
    public var errors: [String] = []
    public var warnings: [String] = []
    public var engineVersion: String? = nil
    public var fixedEndMomentA: Double? = nil  // kN·m (interno; negativo = tração em cima)
    public var fixedEndMomentB: Double? = nil
    public var shearCurve: [ShearPoint] = []
    public var momentCurve: [MomentPoint] = []
    public var deflectionCurve: [DeflectionPoint] = []
    public var vonMisesCurve: [VonMisesPoint] = []

    public init() {}
}
