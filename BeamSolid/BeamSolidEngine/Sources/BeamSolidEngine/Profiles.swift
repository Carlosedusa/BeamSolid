/**
 * BeamSolidEngine — Catálogo de aços e perfis
 * Porte fiel de `src/data/profiles.ts` do BeamSolid Pro (web). Mesmos 2 aços e 12 perfis,
 * com os mesmos valores numéricos — necessário para os testes baterem com o motor web.
 */
import Foundation

public let STEEL_GRADES: [SteelGrade] = [
    SteelGrade(name: "ASTM A36", category: "AÇO CARBONO", fy: 250, fu: 400, E: 200, G: 77.2, nu: 0.30),
    SteelGrade(name: "A572 Gr 50", category: "ALTA RESISTÊNCIA", fy: 345, fu: 450, E: 200, G: 77.2, nu: 0.30),
]

public let STEEL_PROFILES: [SteelProfile] = [
    SteelProfile(
        id: "w-250-32-7", designation: "W 250 x 32.7", family: "W",
        typeDescription: "Perfil W Gerdau • Flange Larga Laminado AISC",
        massLinear: 32.7, depth_d: 258, flangeWidth_bf: 146, webThickness_tw: 6.1,
        flangeThickness_tf: 9.1, area_A: 42.1, inertia_Ix: 4890, inertia_Iy: 473,
        elasticModulus_Wx: 379.3, plasticModulus_Zx: 424.3, radiusGyration_rx: 10.78,
        radiusGyration_ry: 3.35, webCompact: true, flangeCompact: true, tag: "PADRÃO"
    ),
    SteelProfile(
        id: "w-200-31-3", designation: "W 200 x 31.3", family: "W",
        typeDescription: "Perfil W mais compacto para pé-direito reduzido",
        massLinear: 31.3, depth_d: 210, flangeWidth_bf: 134, webThickness_tw: 6.4,
        flangeThickness_tf: 10.2, area_A: 39.8, inertia_Ix: 3168, inertia_Iy: 408,
        elasticModulus_Wx: 298.2, plasticModulus_Zx: 334.5, radiusGyration_rx: 8.92,
        radiusGyration_ry: 3.20, webCompact: true, flangeCompact: true, savingsVsW250: "-1.4 kg/m"
    ),
    SteelProfile(
        id: "w-310-28-3", designation: "W 310 x 28.3", family: "W",
        typeDescription: "Maior inércia flexional e peso reduzido (d=309 mm)",
        massLinear: 28.3, depth_d: 309, flangeWidth_bf: 102, webThickness_tw: 6.0,
        flangeThickness_tf: 8.9, area_A: 36.1, inertia_Ix: 5446, inertia_Iy: 158,
        elasticModulus_Wx: 356.1, plasticModulus_Zx: 409.2, radiusGyration_rx: 12.28,
        radiusGyration_ry: 2.09, webCompact: true, flangeCompact: true,
        tag: "MAIS LEVE", savingsVsW250: "-13.4%"
    ),
    SteelProfile(
        id: "w-310-38-7", designation: "W 310 x 38.7", family: "W",
        typeDescription: "Perfil de alta rigidez para vãos médios e balanços",
        massLinear: 38.7, depth_d: 310, flangeWidth_bf: 165, webThickness_tw: 5.8,
        flangeThickness_tf: 9.7, area_A: 49.3, inertia_Ix: 8520, inertia_Iy: 727,
        elasticModulus_Wx: 549.7, plasticModulus_Zx: 615.0, radiusGyration_rx: 13.15,
        radiusGyration_ry: 3.84, webCompact: true, flangeCompact: true
    ),
    SteelProfile(
        id: "w-200-22-5", designation: "W 200 x 22.5", family: "W",
        typeDescription: "Perfil leve para passarelas e terças de cobertura",
        massLinear: 22.5, depth_d: 206, flangeWidth_bf: 102, webThickness_tw: 6.2,
        flangeThickness_tf: 8.0, area_A: 28.6, inertia_Ix: 2000, inertia_Iy: 142,
        elasticModulus_Wx: 194.2, plasticModulus_Zx: 222.0, radiusGyration_rx: 8.36,
        radiusGyration_ry: 2.23, webCompact: true, flangeCompact: true
    ),
    SteelProfile(
        id: "w-360-44-0", designation: "W 360 x 44.0", family: "W",
        typeDescription: "Viga principal de cobertura e mezaninos pesados",
        massLinear: 44.0, depth_d: 352, flangeWidth_bf: 171, webThickness_tw: 6.9,
        flangeThickness_tf: 9.8, area_A: 56.1, inertia_Ix: 12100, inertia_Iy: 816,
        elasticModulus_Wx: 687.5, plasticModulus_Zx: 772.0, radiusGyration_rx: 14.69,
        radiusGyration_ry: 3.82, webCompact: true, flangeCompact: true
    ),
    SteelProfile(
        id: "w-150-18-0", designation: "W 150 x 18.0", family: "W",
        typeDescription: "Perfil compacto para vigamentos secundários e lintéis",
        massLinear: 18.0, depth_d: 153, flangeWidth_bf: 102, webThickness_tw: 5.8,
        flangeThickness_tf: 7.1, area_A: 22.9, inertia_Ix: 928, inertia_Iy: 126,
        elasticModulus_Wx: 121.3, plasticModulus_Zx: 139.1, radiusGyration_rx: 6.36,
        radiusGyration_ry: 2.35, webCompact: true, flangeCompact: true
    ),
    SteelProfile(
        id: "i-203-27-4", designation: "I 203 x 27.4", family: "I",
        typeDescription: "Perfil I American Standard (S 8x18.4)",
        massLinear: 27.4, depth_d: 203, flangeWidth_bf: 102, webThickness_tw: 6.9,
        flangeThickness_tf: 10.8, area_A: 34.9, inertia_Ix: 2370, inertia_Iy: 195,
        elasticModulus_Wx: 233.5, plasticModulus_Zx: 271.0, radiusGyration_rx: 8.24,
        radiusGyration_ry: 2.36, webCompact: true, flangeCompact: true
    ),
    SteelProfile(
        id: "u-200-20-5", designation: "U 200 x 20.5", family: "U",
        typeDescription: "Canal estrutural padrão Gerdau / C-channel",
        massLinear: 20.5, depth_d: 203, flangeWidth_bf: 71, webThickness_tw: 7.1,
        flangeThickness_tf: 9.9, area_A: 26.1, inertia_Ix: 1480, inertia_Iy: 98,
        elasticModulus_Wx: 145.8, plasticModulus_Zx: 172.0, radiusGyration_rx: 7.53,
        radiusGyration_ry: 1.94, webCompact: true, flangeCompact: true
    ),
    SteelProfile(
        id: "hss-200-100-6-3", designation: "HSS 200x100x6.3", family: "HSS",
        typeDescription: "Tubo estrutural retangular laminado a quente",
        massLinear: 27.4, depth_d: 200, flangeWidth_bf: 100, webThickness_tw: 6.3,
        flangeThickness_tf: 6.3, area_A: 34.9, inertia_Ix: 1870, inertia_Iy: 640,
        elasticModulus_Wx: 187.0, plasticModulus_Zx: 228.0, radiusGyration_rx: 7.32,
        radiusGyration_ry: 4.28, webCompact: true, flangeCompact: true
    ),
    SteelProfile(
        id: "pipe-114-3-4-5", designation: "Tubo Ø 114.3 x 4.5", family: "TUB_CIRC",
        typeDescription: "Tubo estrutural circular sem costura (NBR 8261 / ASTM A500)",
        massLinear: 12.18, depth_d: 114.3, flangeWidth_bf: 114.3, webThickness_tw: 4.5,
        flangeThickness_tf: 4.5, area_A: 15.52, inertia_Ix: 231.2, inertia_Iy: 231.2,
        elasticModulus_Wx: 40.46, plasticModulus_Zx: 54.34, radiusGyration_rx: 3.86,
        radiusGyration_ry: 3.86, webCompact: true, flangeCompact: true
    ),
    SteelProfile(
        id: "pipe-168-3-4-8", designation: "Tubo Ø 168.3 x 4.8", family: "TUB_CIRC",
        typeDescription: "Tubo estrutural circular padrão Gerdau / Vallourec (6\")",
        massLinear: 19.35, depth_d: 168.3, flangeWidth_bf: 168.3, webThickness_tw: 4.8,
        flangeThickness_tf: 4.8, area_A: 24.65, inertia_Ix: 814.5, inertia_Iy: 814.5,
        elasticModulus_Wx: 96.79, plasticModulus_Zx: 128.5, radiusGyration_rx: 5.75,
        radiusGyration_ry: 5.75, webCompact: true, flangeCompact: true
    ),
]

public let DEFAULT_PROFILE: SteelProfile = STEEL_PROFILES[0]
