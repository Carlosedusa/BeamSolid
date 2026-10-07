/**
 * BeamSolidEngine — Motor de cálculo estrutural
 *
 * Porte LINHA A LINHA de `src/utils/structuralSolver.ts` (BeamSolid Pro, web), validado lá com
 * 39/39 verificações contra soluções analíticas de manual. Qualquer alteração de lógica aqui deve
 * ser espelhada no arquivo TypeScript (e vice-versa) para as duas versões não divergirem.
 *
 * Método: elementos finitos de viga de Euler-Bernoulli (2 GDL por nó: w, θ), com nós em todos os
 * pontos singulares (apoios, início/fim de cargas, cargas pontuais e momentos). Com cargas
 * uniformes por trecho, o resultado é EXATO (esforços e flecha), sem amostragem.
 *
 * Convenções (iguais às do app web):
 *  - V(x) > 0 : soma das forças verticais à esquerda da seção, para cima
 *  - M(x) > 0 : momento fletor que traciona a fibra inferior (sagging); engaste = negativo
 *  - flecha   : positiva para baixo (mm)
 *  - carga distribuída/pontual: valor ≥ 0, direção .down (para baixo) ou .up (para cima)
 *  - momento aplicado: valor ≥ 0, horário quando .down (anti-horário quando .up)
 *
 * Segurança: entradas inválidas (NaN, Infinity, fora do vão, perfil/aço corrompido) NUNCA
 * produzem PASS. O resultado é status .invalid com a lista de erros (fail-closed). O motor também
 * confere o equilíbrio global (forças e momentos) de cada resolução.
 */
import Foundation

public let ENGINE_VERSION = "2.0.0-swift"
public let GAMMA_A1 = 1.10          // NBR 8800:2008 — escoamento
public let DEFLECTION_DIVISOR = 350.0 // NBR 8800:2008 Anexo C (vigas de piso: L/350)
private let MIN_SPAN = 0.5
private let MAX_SPAN = 200.0
private let TOL_X = 1e-9
private let TARGET_SAMPLES = 240
// m: dedup de pontos "crus" praticamente idênticos (ruído de ponto flutuante). A prevenção de
// elementos degenerados de verdade é feita pelo agrupamento com MIN_ELEM, logo abaixo.
private let SNAP = 1e-3
// m: nós finais a menos de 2 cm um do outro são fundidos num só (ver o agrupamento em solveBeam).
// Um elemento com l < MIN_ELEM tem rigidez EI/l³ muitas ordens de grandeza maior que a dos
// vizinhos, o que mal-condiciona o sistema e pode levar o motor a recusar a resposta (.invalid)
// mesmo quando as cargas estão fisicamente só "quase no mesmo ponto" — 2 cm é abaixo de qualquer
// precisão de posicionamento de carga com sentido estrutural prático.
private let MIN_ELEM = 0.02

private func r1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
private func r2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
private func r3(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }
/// Arredondamento conservador (nunca reduz a razão exibida).
private func ceil1(_ v: Double) -> Double { (v * 10 - 1e-9).rounded(.up) / 10 }

// MARK: - Validação (fail-closed)

private struct Geometry {
    var L: Double
    var posA: Double
    var posB: Double
    var posC: Double?
}

private func validate(
    spanLength: Double, supportType: SupportType, loads: [LoadItem],
    profile: SteelProfile?, grade: SteelGrade?, sp: SupportPositions?
) -> (errors: [String], warnings: [String], geo: Geometry?) {
    var errors: [String] = []
    var warnings: [String] = []

    if !spanLength.isFinite || spanLength < MIN_SPAN || spanLength > MAX_SPAN {
        errors.append("Vão inválido (\(spanLength)). Use valores entre \(MIN_SPAN) m e \(MAX_SPAN) m.")
    }

    if let profile = profile {
        let checks: [(String, Double)] = [
            ("depth_d", profile.depth_d), ("webThickness_tw", profile.webThickness_tw),
            ("flangeThickness_tf", profile.flangeThickness_tf), ("inertia_Ix", profile.inertia_Ix),
            ("elasticModulus_Wx", profile.elasticModulus_Wx), ("plasticModulus_Zx", profile.plasticModulus_Zx),
            ("area_A", profile.area_A),
        ]
        for (k, v) in checks where !v.isFinite || v <= 0 {
            errors.append("Propriedade do perfil inválida: \(k) = \(v).")
        }
    } else {
        errors.append("Perfil não informado.")
    }

    if let grade = grade {
        if !grade.fy.isFinite || grade.fy < 100 || grade.fy > 1500 {
            errors.append("fy inválido: \(grade.fy) MPa.")
        }
        if !grade.E.isFinite || grade.E < 50 || grade.E > 400 {
            errors.append("E inválido: \(grade.E) GPa.")
        }
    } else {
        errors.append("Aço não informado.")
    }
    if !errors.isEmpty { return (errors, warnings, nil) }

    let L = spanLength
    let posA = sp?.posA ?? 0
    let posB = sp?.posB ?? L
    var posC = sp?.posC

    if !posA.isFinite || posA < -TOL_X || posA > L + TOL_X {
        errors.append("Posição do apoio A inválida (\(posA)).")
    }
    if supportType == .cantilever {
        if posA.isFinite && posA > L - 0.1 {
            errors.append("Engaste muito próximo da extremidade livre da viga.")
        }
    } else {
        if !posB.isFinite || posB > L + TOL_X {
            errors.append("Posição do apoio B inválida (\(posB)), fora do vão \(L) m.")
        } else if posA.isFinite && posB - posA < 0.1 {
            errors.append("A distância entre os apoios A e B deve ser de pelo menos 0,1 m.")
        }
    }
    if supportType == .continua && errors.isEmpty {
        if posC == nil { posC = (posA + posB) / 2 }
        let pc = posC!
        if !pc.isFinite || pc < posA + 0.05 || pc > posB - 0.05 {
            errors.append("Posição do apoio intermediário C inválida (\(pc)).")
        }
    }

    for (i, ld) in loads.enumerated() {
        let tag = "Carga \(i + 1)" + (ld.name.isEmpty ? "" : " (\(ld.name))")
        if !ld.value.isFinite || ld.value < 0 {
            errors.append("\(tag): valor inválido (\(ld.value)). Use valor ≥ 0 e a direção para o sentido.")
        }
        if !ld.gammaF.isFinite || ld.gammaF <= 0 || ld.gammaF > 3 {
            errors.append("\(tag): coeficiente γf inválido (\(ld.gammaF)).")
        }
        if !ld.positionX.isFinite || ld.positionX < -TOL_X || ld.positionX > L + TOL_X {
            errors.append("\(tag): posição \(ld.positionX) m fora da viga (0 a \(L) m).")
        } else if ld.type == .distributed {
            if let len = ld.length, !len.isFinite || len < 0 {
                errors.append("\(tag): comprimento inválido (\(len)).")
            } else if ld.positionX + (ld.length ?? L) > L + TOL_X {
                warnings.append("\(tag): estende além da viga e foi limitada ao comprimento de \(L) m.")
            }
        }
    }
    if !errors.isEmpty { return (errors, warnings, nil) }

    let geo = Geometry(
        L: L, posA: max(0, posA),
        posB: supportType == .cantilever ? L : min(posB, L),
        posC: posC
    )
    return (errors, warnings, geo)
}

// MARK: - Álgebra linear mínima

/// Gauss com pivotamento parcial e equilíbrio diagonal (Jacobi scaling) — robusto com elementos
/// de magnitudes muito diferentes na matriz de rigidez. Retorna nil se o sistema for singular
/// (estrutura instável/hipostática).
private func solveLinear(_ A0: [[Double]], _ b0: [Double]) -> [Double]? {
    let n = b0.count
    if n == 0 { return [] }
    var dsc = [Double](repeating: 0, count: n)
    for i in 0..<n { dsc[i] = abs(A0[i][i]).squareRoot() }
    for d in dsc where !(d > 0) || !d.isFinite { return nil }

    var M = [[Double]](repeating: [Double](repeating: 0, count: n + 1), count: n)
    for i in 0..<n {
        for j in 0..<n { M[i][j] = A0[i][j] / (dsc[i] * dsc[j]) }
        M[i][n] = b0[i] / dsc[i]
    }
    for c in 0..<n {
        var p = c
        for r in (c + 1)..<n where abs(M[r][c]) > abs(M[p][c]) { p = r }
        if abs(M[p][c]) < 1e-9 { return nil }
        if p != c { M.swapAt(c, p) }
        for r in (c + 1)..<n {
            let f = M[r][c] / M[c][c]
            if f == 0 { continue }
            for k in c...n { M[r][k] -= f * M[c][k] }
        }
    }
    var y = [Double](repeating: 0, count: n)
    for i in stride(from: n - 1, through: 0, by: -1) {
        var s = M[i][n]
        for k in (i + 1)..<n { s -= M[i][k] * y[k] }
        y[i] = s / M[i][i]
    }
    return (0..<n).map { y[$0] / dsc[$0] }
}

// MARK: - Núcleo: resolve um caso de carga (ELU majorado ou ELS característico)

private struct Elem { var x0: Double; var l: Double; var q: Double } // q: kN/m, + para baixo

private struct CaseSolution {
    var u: [Double]
    var p: [[Double]]           // forças nodais no elemento [F1,M1,F2,M2] (F↑, M anti-horário)
    var reactionsV: [Double]    // por nó
    var reactionsM: [Double]    // por nó (anti-horário)
    var totalDown: Double
    var errors: [String]
    var elems: [Elem]
}

private func ke(_ EI: Double, _ l: Double) -> [[Double]] {
    let c = EI / (l * l * l)
    return [
        [12 * c, 6 * l * c, -12 * c, 6 * l * c],
        [6 * l * c, 4 * l * l * c, -6 * l * c, 2 * l * l * c],
        [-12 * c, -6 * l * c, 12 * c, -6 * l * c],
        [6 * l * c, 2 * l * l * c, -6 * l * c, 4 * l * l * c],
    ]
}

private func feq(_ q: Double, _ l: Double) -> [Double] {
    [-q * l / 2, -q * l * l / 12, -q * l / 2, q * l * l / 12]
}

private func buildElems(_ xs: [Double], _ loads: [LoadItem], _ L: Double, _ factorOf: (LoadItem) -> Double) -> [Elem] {
    var es: [Elem] = []
    for i in 0..<(xs.count - 1) { es.append(Elem(x0: xs[i], l: xs[i + 1] - xs[i], q: 0)) }
    for ld in loads where ld.type == .distributed {
        let f = factorOf(ld)
        let q = ld.value * f * (ld.direction == .up ? -1.0 : 1.0)
        let xa = ld.positionX
        let xb = min(ld.positionX + (ld.length ?? L), L)
        for i in 0..<es.count where es[i].x0 >= xa - TOL_X && es[i].x0 + es[i].l <= xb + TOL_X {
            es[i].q += q
        }
    }
    return es
}

private func solveCase(
    xs: [Double], EI: Double, loads: [LoadItem], L: Double,
    factorOf: (LoadItem) -> Double, supports: [(node: Int, fixed: Bool)]
) -> CaseSolution {
    let nN = xs.count
    let nD = 2 * nN
    let elems = buildElems(xs, loads, L, factorOf)
    func nodeAt(_ x: Double) -> Int { xs.firstIndex(where: { abs($0 - x) < 1e-7 }) ?? -1 }

    var F = [Double](repeating: 0, count: nD)
    var totalDown = 0.0
    var momentAbout0 = 0.0 // só para a checagem de equilíbrio (anti-horário +)

    for ld in loads {
        let f = factorOf(ld)
        let s: Double = ld.direction == .up ? -1 : 1 // s = +1: para baixo
        switch ld.type {
        case .distributed:
            let xa = ld.positionX
            let xb = min(ld.positionX + (ld.length ?? L), L)
            let q = ld.value * f * s
            totalDown += q * (xb - xa)
            momentAbout0 += -q * (xb - xa) * ((xa + xb) / 2)
        case .point:
            let P = ld.value * f * s
            let idx = nodeAt(ld.positionX)
            if idx >= 0 { F[2 * idx] += -P }
            totalDown += P
            momentAbout0 += -P * ld.positionX
        case .moment:
            let M0 = ld.value * f * s // horário positivo quando s = +1
            let idx = nodeAt(ld.positionX)
            if idx >= 0 { F[2 * idx + 1] += -M0 }
            momentAbout0 += -M0
        }
    }

    var K = [[Double]](repeating: [Double](repeating: 0, count: nD), count: nD)
    for (i, e) in elems.enumerated() {
        let k = ke(EI, e.l)
        let fe = feq(e.q, e.l)
        let dof = [2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 3]
        for a in 0..<4 {
            F[dof[a]] += fe[a]
            for b in 0..<4 { K[dof[a]][dof[b]] += k[a][b] }
        }
    }

    var fixedDof = Set<Int>()
    for sup in supports {
        fixedDof.insert(2 * sup.node)
        if sup.fixed { fixedDof.insert(2 * sup.node + 1) }
    }
    let free = (0..<nD).filter { !fixedDof.contains($0) }
    let Asub = free.map { i in free.map { j in K[i][j] } }
    let bsub = free.map { F[$0] }

    var errors: [String] = []
    var u = [Double](repeating: 0, count: nD)
    guard let uf = solveLinear(Asub, bsub) else {
        errors.append("Estrutura instável ou mal condicionada (verifique os apoios).")
        return CaseSolution(u: u, p: [], reactionsV: [], reactionsM: [], totalDown: totalDown, errors: errors, elems: elems)
    }
    for (idx, d) in free.enumerated() { u[d] = uf[idx] }

    // Reações: R = K·u − F nos GDL restritos
    var reactionsV = [Double](repeating: 0, count: nN)
    var reactionsM = [Double](repeating: 0, count: nN)
    var termScale = 0.0 // magnitude dos termos somados em R (para a folga de arredondamento)
    for d in fixedDof {
        var r = -F[d]
        var t = abs(F[d])
        for j in 0..<nD {
            r += K[d][j] * u[j]
            t += abs(K[d][j] * u[j])
        }
        termScale = max(termScale, t)
        if d % 2 == 0 { reactionsV[d / 2] = r } else { reactionsM[(d - 1) / 2] = r }
    }

    // Forças nodais nos elementos: p = Ke·u − fe
    var p: [[Double]] = []
    for (i, e) in elems.enumerated() {
        let k = ke(EI, e.l)
        let fe = feq(e.q, e.l)
        let ue = [u[2 * i], u[2 * i + 1], u[2 * i + 2], u[2 * i + 3]]
        var row = [Double](repeating: 0, count: 4)
        for a in 0..<4 {
            var s = 0.0
            for b in 0..<4 { s += k[a][b] * ue[b] }
            row[a] = s - fe[a]
        }
        p.append(row)
    }

    // Conferência de equilíbrio global (forças e momentos)
    let sumR = reactionsV.reduce(0, +)
    let scaleF = max(1.0, abs(totalDown), reactionsV.map { abs($0) }.max() ?? 0)
    // Folga de arredondamento proporcional à escala dos termos, limitada a 1 N:
    // evita falso positivo em malhas com elementos muito curtos, sem mascarar erros reais.
    let roundoff = min(1e-8 * termScale, 1e-3)
    if abs(sumR - totalDown) > 1e-6 * scaleF + roundoff {
        errors.append("Falha de equilíbrio de forças no motor de cálculo.")
    }
    var sumM0 = momentAbout0
    for (i, r) in reactionsV.enumerated() { sumM0 += r * xs[i] }
    for m in reactionsM { sumM0 += m }
    let scaleM = max(1.0, abs(momentAbout0), (0..<reactionsV.count).map { abs(reactionsV[$0] * xs[$0]) }.max() ?? 0)
    if abs(sumM0) > 1e-6 * scaleM + roundoff * max(1.0, L) {
        errors.append("Falha de equilíbrio de momentos no motor de cálculo.")
    }

    return CaseSolution(u: u, p: p, reactionsV: reactionsV, reactionsM: reactionsM, totalDown: totalDown, errors: errors, elems: elems)
}

// Funções exatas dentro de um elemento (s ∈ [0, l])
private func V_at(_ p: [Double], _ q: Double, _ s: Double) -> Double { p[0] - q * s }
private func M_at(_ p: [Double], _ q: Double, _ s: Double) -> Double { -p[1] + p[0] * s - (q * s * s) / 2 }

private func w_up(_ u: [Double], _ i: Int, _ l: Double, _ q: Double, _ EI: Double, _ s: Double) -> Double {
    let xi = s / l
    let xi3 = xi * xi * xi
    let H1 = 1 - 3 * xi * xi + 2 * xi3
    let H2 = l * (xi - 2 * xi * xi + xi3)
    let H3 = 3 * xi * xi - 2 * xi3
    let H4 = l * (-xi * xi + xi3)
    let herm = H1 * u[2 * i] + H2 * u[2 * i + 1] + H3 * u[2 * i + 2] + H4 * u[2 * i + 3]
    return herm - (q * s * s * (l - s) * (l - s)) / (24 * EI)
}

// MARK: - Resultado inválido (fail-closed)

private func invalidResult(_ L: Double, _ errors: [String], _ warnings: [String] = []) -> CalculationResults {
    let Lx = r3(L.isFinite && L > 0 ? L : 1)
    var out = CalculationResults()
    out.status = .invalid
    out.errors = errors
    out.warnings = warnings
    out.engineVersion = ENGINE_VERSION
    out.shearCurve = [ShearPoint(x: 0, v: 0), ShearPoint(x: Lx, v: 0)]
    out.momentCurve = [MomentPoint(x: 0, m: 0), MomentPoint(x: Lx, m: 0)]
    out.deflectionCurve = [DeflectionPoint(x: 0, d: 0), DeflectionPoint(x: Lx, d: 0)]
    out.vonMisesCurve = [VonMisesPoint(x: 0, vm: 0, sigma: 0, tau: 0), VonMisesPoint(x: Lx, vm: 0, sigma: 0, tau: 0)]
    return out
}

// MARK: - API pública

public func solveBeam(
    spanLength: Double,
    supportType: SupportType,
    loads: [LoadItem],
    profile: SteelProfile,
    steelGrade: SteelGrade,
    supportPositions: SupportPositions? = nil
) -> CalculationResults {
    let v = validate(spanLength: spanLength, supportType: supportType, loads: loads, profile: profile, grade: steelGrade, sp: supportPositions)
    guard v.errors.isEmpty, let geo = v.geo else {
        return invalidResult(spanLength, v.errors, v.warnings)
    }
    let L = geo.L, posA = geo.posA, posB = geo.posB, posC = geo.posC
    var warnings = v.warnings

    // Malha — duas etapas:
    // 1) coleta de pontos "crus" (âncoras + extremos de cada carga), deduplicados a 1 mm (SNAP);
    // 2) agrupamento (clustering) de pontos crus a menos de MIN_ELEM um do outro, para nunca gerar
    //    um elemento quase degenerado entre dois pontos que, na prática, estão "no mesmo lugar".
    //    Uma âncora (apoio/extremo) nunca é deslocada: se cair no mesmo grupo de um ponto de carga,
    //    o grupo inteiro assume a posição exata da âncora. validate() já garante pelo menos 0,10 m
    //    entre apoios A/B e 0,05 m do apoio C a cada lado — bem acima de MIN_ELEM — então dois
    //    apoios nunca caem no mesmo grupo.
    var rawXs: [Double] = []
    var isAnchorRaw: [Bool] = []
    @discardableResult
    func addRaw(_ x: Double, anchor: Bool) -> Int {
        let c = min(max(x, 0), L)
        if let near = rawXs.firstIndex(where: { abs($0 - c) < SNAP }) {
            if anchor { isAnchorRaw[near] = true }
            return near
        }
        rawXs.append(c)
        isAnchorRaw.append(anchor)
        return rawXs.count - 1
    }
    addRaw(0, anchor: true)
    addRaw(L, anchor: true)
    addRaw(posA, anchor: true)
    if supportType != .cantilever { addRaw(posB, anchor: true) }
    if supportType == .continua, let pc = posC { addRaw(pc, anchor: true) }

    struct LoadNodeIdx { var xa: Int; var xb: Int? }
    let loadIdx: [LoadNodeIdx] = loads.map { ld in
        let xa = addRaw(ld.positionX, anchor: false)
        if ld.type != .distributed { return LoadNodeIdx(xa: xa, xb: nil) }
        let xbRaw = min(ld.positionX + (ld.length ?? L), L)
        let xb = addRaw(xbRaw, anchor: false)
        return LoadNodeIdx(xa: xa, xb: xb)
    }

    // Agrupamento por encadeamento simples (single-linkage) em 1D: percorre os pontos crus em
    // ordem crescente; começa um grupo novo sempre que o vão até o ponto anterior for ≥ MIN_ELEM.
    let order = (0..<rawXs.count).sorted { rawXs[$0] < rawXs[$1] }
    var clusterOfRaw = [Int](repeating: 0, count: rawXs.count)
    var cid = 0
    clusterOfRaw[order[0]] = 0
    for k in 1..<order.count {
        if rawXs[order[k]] - rawXs[order[k - 1]] >= MIN_ELEM { cid += 1 }
        clusterOfRaw[order[k]] = cid
    }
    var clusterAnchorValue: [Int: Double] = [:]
    var clusterFirstValue: [Int: Double] = [:]
    for i in order {
        let c = clusterOfRaw[i]
        if clusterFirstValue[c] == nil { clusterFirstValue[c] = rawXs[i] }
        if isAnchorRaw[i] && clusterAnchorValue[c] == nil { clusterAnchorValue[c] = rawXs[i] }
    }
    func finalOf(_ i: Int) -> Double {
        let c = clusterOfRaw[i]
        return clusterAnchorValue[c] ?? clusterFirstValue[c]!
    }

    var xsSet = Set<Double>()
    for i in 0..<rawXs.count { xsSet.insert(finalOf(i)) }
    let xs = xsSet.sorted()
    func nodeAt(_ x: Double) -> Int { xs.firstIndex(where: { abs($0 - x) < SNAP }) ?? -1 }

    var maxShift = 0.0
    let effLoads: [LoadItem] = loads.enumerated().map { (i, ld) -> LoadItem in
        var ld2 = ld
        let xa = finalOf(loadIdx[i].xa)
        maxShift = max(maxShift, abs(xa - ld.positionX))
        if ld.type != .distributed {
            ld2.positionX = xa
            return ld2
        }
        let xbRaw = min(ld.positionX + (ld.length ?? L), L)
        let xb = finalOf(loadIdx[i].xb!)
        maxShift = max(maxShift, abs(xb - xbRaw))
        ld2.positionX = xa
        ld2.length = max(0, xb - xa)
        return ld2
    }
    if maxShift > 1e-6 {
        warnings.append("Posições de carga alinhadas à malha de cálculo (deslocamento máximo \(String(format: "%.2f", maxShift * 1000)) mm).")
    }

    var supports: [(node: Int, fixed: Bool)] = []
    switch supportType {
    case .biapoiada: supports = [(nodeAt(posA), false), (nodeAt(posB), false)]
    case .cantilever: supports = [(nodeAt(posA), true)]
    case .biengastada: supports = [(nodeAt(posA), true), (nodeAt(posB), true)]
    case .continua: supports = [(nodeAt(posA), false), (nodeAt(posC!), false), (nodeAt(posB), false)]
    }

    let EI = steelGrade.E * 1e6 * profile.inertia_Ix * 1e-8 // kN·m²

    // ELU (majorado) para V, M e reações; ELS (γf = 1) para flecha
    let uls = solveCase(xs: xs, EI: EI, loads: effLoads, L: L, factorOf: { $0.gammaF }, supports: supports)
    let sls = solveCase(xs: xs, EI: EI, loads: effLoads, L: L, factorOf: { _ in 1.0 }, supports: supports)
    let errs = uls.errors + sls.errors
    if !errs.isEmpty { return invalidResult(L, errs, warnings) }
    let elU = uls.elems, elS = sls.elems

    struct Sample { var e: Int; var s: Double; var x: Double }
    var samples: [Sample] = []
    for (i, e) in elU.enumerated() {
        let n = max(4, Int((Double(TARGET_SAMPLES) * e.l / L).rounded(.up)))
        var ss = Set<Double>()
        for k in 0...n { ss.insert(Double(k) * e.l / Double(n)) }
        if abs(e.q) > 1e-12 {
            let s0 = uls.p[i][0] / e.q
            if s0 > 1e-9 && s0 < e.l - 1e-9 { ss.insert(s0) }
        }
        for s in ss.sorted() { samples.append(Sample(e: i, s: s, x: e.x0 + s)) }
    }

    let Vs = samples.map { V_at(uls.p[$0.e], elU[$0.e].q, $0.s) }
    let Ms = samples.map { M_at(uls.p[$0.e], elU[$0.e].q, $0.s) }
    let Ws = samples.map { -w_up(sls.u, $0.e, elS[$0.e].l, elS[$0.e].q, EI, $0.s) * 1000 } // mm, + para baixo

    // Extremos
    var maxShearPos = 0.0, maxShearNeg = 0.0, maxMoment = 0.0, maxMomentX = (posA + posB) / 2
    for (i, sm) in samples.enumerated() {
        if Vs[i] > maxShearPos { maxShearPos = Vs[i] }
        if Vs[i] < maxShearNeg { maxShearNeg = Vs[i] }
        if abs(Ms[i]) > abs(maxMoment) { maxMoment = Ms[i]; maxMomentX = sm.x }
    }

    // Flecha máxima com refinamento (seção áurea) em torno da melhor amostra
    var kBest = 0
    for i in 0..<Ws.count where abs(Ws[i]) > abs(Ws[kBest]) { kBest = i }
    var maxDeflection = Ws[kBest]
    var maxDeflectionX = samples[kBest].x
    do {
        let e = samples[kBest].e
        func wAbs(_ s: Double) -> Double { abs(w_up(sls.u, e, elS[e].l, elS[e].q, EI, s) * 1000) }
        var a = max(0.0, samples[kBest].s - elS[e].l / 4)
        var b = min(elS[e].l, samples[kBest].s + elS[e].l / 4)
        let g = (5.0.squareRoot() - 1) / 2
        for _ in 0..<60 {
            let c1 = b - g * (b - a), c2 = a + g * (b - a)
            if wAbs(c1) > wAbs(c2) { b = c2 } else { a = c1 }
        }
        let sMid = (a + b) / 2
        let wMid = -w_up(sls.u, e, elS[e].l, elS[e].q, EI, sMid) * 1000
        if abs(wMid) > abs(maxDeflection) { maxDeflection = wMid; maxDeflectionX = elS[e].x0 + sMid }
    }

    // Cruzamento de cortante (+ → −) com maior |M|
    var shearZeroX = (posA + posB) / 2
    var bestAbsM = -1.0
    if samples.count > 1 {
        for i in 1..<samples.count where Vs[i - 1] >= 0 && Vs[i] < 0 {
            let dx = samples[i].x - samples[i - 1].x
            let xz = dx < 1e-9 ? samples[i].x : samples[i - 1].x + dx * Vs[i - 1] / (Vs[i - 1] - Vs[i])
            let mAbs = max(abs(Ms[i - 1]), abs(Ms[i]))
            if mAbs > bestAbsM { bestAbsM = mAbs; shearZeroX = xz }
        }
    }

    // Capacidades resistentes (seção compacta, contenção lateral contínua — ver LIMITACOES.md)
    let allowableStress_fyd = steelGrade.fy / GAMMA_A1
    let momentCapacity_Mrd = (profile.plasticModulus_Zx * steelGrade.fy) / (GAMMA_A1 * 1000)
    let Aw_mm2 = profile.depth_d * profile.webThickness_tw
    let shearCapacity_Vrd = (0.6 * (Aw_mm2 / 100) * steelGrade.fy) / (GAMMA_A1 * 10)
    let Wx = profile.elasticModulus_Wx

    let d = max(profile.depth_d, 10), tf = max(profile.flangeThickness_tf, 1)
    let webFlangeRatio = d > 2 * tf ? (d - 2 * tf) / d : 0.85

    var normalStressMax = 0.0, normalStressMaxX = maxMomentX
    var shearStressMax = 0.0, shearStressMaxX = posA
    var vonMisesMax = 0.0, vonMisesMaxX = maxMomentX
    var vonMisesCurve: [VonMisesPoint] = []
    for (i, sm) in samples.enumerated() {
        let sigma = abs(Ms[i]) * 1000 / Wx
        let tau = abs(Vs[i]) * 1000 / Aw_mm2
        let sj = sigma * webFlangeRatio
        let vmJ = (sj * sj + 3 * tau * tau).squareRoot()
        let vm = max(sigma, 3.0.squareRoot() * tau, vmJ)
        if sigma > normalStressMax { normalStressMax = sigma; normalStressMaxX = sm.x }
        if tau > shearStressMax { shearStressMax = tau; shearStressMaxX = sm.x }
        if vm > vonMisesMax { vonMisesMax = vm; vonMisesMaxX = sm.x }
        vonMisesCurve.append(VonMisesPoint(x: r3(sm.x), vm: r2(vm), sigma: r2(sigma), tau: r2(tau)))
    }

    // Flecha admissível (L/350). Balanço: o L da Tabela C.1 é o dobro do comprimento do balanço.
    let Lref: Double
    if supportType == .cantilever { Lref = 2 * (L - posA) }
    else if supportType == .continua { Lref = max(posC! - posA, posB - posC!) }
    else { Lref = posB - posA }
    let allowableDeflection = (Lref * 1000) / DEFLECTION_DIVISOR

    // Razões SEM arredondamento para decidir o status; exibição com arredondamento conservador
    let rM = abs(maxMoment) / momentCapacity_Mrd * 100
    let rV = max(abs(maxShearPos), abs(maxShearNeg)) / shearCapacity_Vrd * 100
    let rD = abs(maxDeflection) / allowableDeflection * 100
    let rVM = vonMisesMax / allowableStress_fyd * 100
    let hasLoads = loads.contains { $0.value > 0 }
    let ratios = [rM, rV, rD, rVM]
    var status: CalcStatus
    if !ratios.allSatisfy({ $0.isFinite }) { status = .invalid }
    else if !hasLoads { status = .none }
    else if ratios.contains(where: { $0 > 100 }) { status = .fail }
    else if ratios.contains(where: { $0 > 85 }) { status = .alert }
    else { status = .pass }

    // Reações
    let rAv = uls.reactionsV[nodeAt(posA)]
    let rBv = supportType == .cantilever ? 0 : uls.reactionsV[nodeAt(posB)]
    let rCv: Double? = supportType == .continua ? uls.reactionsV[nodeAt(posC!)] : nil

    // Momentos nas seções de engaste (interno: negativo = tração em cima)
    var fixedEndMomentA: Double?, fixedEndMomentB: Double?
    if supportType == .cantilever || supportType == .biengastada {
        let iA = nodeAt(posA)
        if iA >= 0 && iA < elU.count { fixedEndMomentA = M_at(uls.p[iA], elU[iA].q, 0) }
    }
    if supportType == .biengastada {
        let iB = nodeAt(posB)
        if iB > 0 { fixedEndMomentB = M_at(uls.p[iB - 1], elU[iB - 1].q, elU[iB - 1].l) }
    }

    var out = CalculationResults()
    out.reactionA = r2(rAv)
    out.reactionB = r2(rBv)
    out.reactionC = rCv.map(r2)
    out.totalVerticalLoad = r2(uls.totalDown)
    out.maxMoment = r2(maxMoment)
    out.maxMomentX = r2(maxMomentX)
    out.maxShearPos = r2(maxShearPos)
    out.maxShearNeg = r2(maxShearNeg)
    out.shearZeroX = r2(shearZeroX)
    out.maxDeflection = r2(maxDeflection)
    out.maxDeflectionX = r2(maxDeflectionX)
    out.allowableDeflection = r1(allowableDeflection)
    out.deflectionRatio = ceil1(rD)
    out.momentCapacity_Mrd = r2(momentCapacity_Mrd)
    out.shearCapacity_Vrd = r2(shearCapacity_Vrd)
    out.momentRatio = ceil1(rM)
    out.shearRatio = ceil1(rV)
    out.normalStressMax = r2(normalStressMax)
    out.normalStressMaxX = r2(normalStressMaxX)
    out.shearStressMax = r2(shearStressMax)
    out.shearStressMaxX = r2(shearStressMaxX)
    out.vonMisesMax = r2(vonMisesMax)
    out.vonMisesMaxX = r2(vonMisesMaxX)
    out.allowableStress_fyd = r1(allowableStress_fyd)
    out.vonMisesRatio = ceil1(rVM)
    out.status = status
    out.warnings = warnings
    out.engineVersion = ENGINE_VERSION
    out.fixedEndMomentA = fixedEndMomentA.map(r2)
    out.fixedEndMomentB = fixedEndMomentB.map(r2)
    out.shearCurve = (0..<samples.count).map { ShearPoint(x: r3(samples[$0].x), v: r2(Vs[$0])) }
    out.momentCurve = (0..<samples.count).map { MomentPoint(x: r3(samples[$0].x), m: r2(Ms[$0])) }
    out.deflectionCurve = (0..<samples.count).map { DeflectionPoint(x: r3(samples[$0].x), d: r3(Ws[$0])) }
    out.vonMisesCurve = vonMisesCurve

    // Última barreira: qualquer número não finito na saída => INVALID
    let numericOk = [
        out.reactionA, out.reactionB, out.totalVerticalLoad, out.maxMoment, out.maxShearPos, out.maxShearNeg,
        out.maxDeflection, out.allowableDeflection, out.deflectionRatio, out.momentCapacity_Mrd,
        out.shearCapacity_Vrd, out.momentRatio, out.shearRatio, out.normalStressMax, out.shearStressMax,
        out.vonMisesMax, out.allowableStress_fyd, out.vonMisesRatio,
    ].allSatisfy { $0.isFinite }
    if !numericOk { return invalidResult(L, ["Resultado numérico não finito (NaN/Infinity)."], warnings) }
    return out
}
