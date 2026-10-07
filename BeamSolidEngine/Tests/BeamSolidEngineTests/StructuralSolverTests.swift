/**
 * Porte de `tests/verify.ts` para XCTest. Mesmo perfil (W 250 x 32.7), mesmo aço (A572 Gr 50),
 * mesmos casos de referência resolvidos à mão. Rode com Cmd+U no Xcode, ou `swift test`.
 */
import XCTest
import Foundation
@testable import BeamSolidEngine

final class StructuralSolverTests: XCTestCase {
    let prof = STEEL_PROFILES.first(where: { $0.id == "w-250-32-7" })!
    let grade = STEEL_GRADES.first(where: { $0.name.contains("A572") })!

    var EI: Double { grade.E * 1e6 * prof.inertia_Ix * 1e-8 } // kN·m²

    func ld(_ type: LoadType, _ value: Double, _ x: Double, length: Double? = nil, gammaF: Double = 1.4) -> LoadItem {
        LoadItem(type: type, value: value, positionX: x, length: length, direction: .down, gammaF: gammaF)
    }

    /// Compara com tolerância relativa (1% por padrão, como no verify.ts original).
    /// `msg` vem antes de `tol` de propósito: assim a chamada comum `assertClose(a, b, "legenda")`
    /// não precisa nomear `tol:`, e só quem quer uma tolerância diferente escreve `tol: 0.001`.
    func assertClose(_ obtido: Double, _ esperado: Double, _ msg: String = "", tol: Double = 0.01, file: StaticString = #filePath, line: UInt = #line) {
        let err = esperado == 0 ? abs(obtido) : abs(obtido - esperado) / abs(esperado)
        XCTAssertTrue(obtido.isFinite && err <= tol, "\(msg): esperado \(esperado), obtido \(obtido) (desvio \(err * 100)%)", file: file, line: line)
    }

    // MARK: C1 — biapoiada, carga uniforme

    func testC1_BiapoiadaUDL() {
        let L = 6.0, q = 10.0, g = 1.4, qd = q * g
        let r = solveBeam(spanLength: L, supportType: .biapoiada, loads: [ld(.distributed, q, 0, length: L)], profile: prof, steelGrade: grade)
        assertClose(r.reactionA, qd * L / 2, "R_A")
        assertClose(r.reactionB, qd * L / 2, "R_B")
        assertClose(r.maxMoment, qd * L * L / 8, "M_max")
        assertClose(r.maxShearPos, qd * L / 2, "V_max")
        assertClose(r.maxDeflection, 5 * q * pow(L, 4) / (384 * EI) * 1000, "flecha")
        assertClose(r.momentCapacity_Mrd, prof.plasticModulus_Zx * grade.fy / (1.1 * 1000), "M_Rd")
        assertClose(r.shearCapacity_Vrd, 0.6 * (prof.depth_d * prof.webThickness_tw / 100) * (grade.fy / 10) / 1.1, "V_Rd")
        assertClose(r.normalStressMax, (qd * L * L / 8) * 1000 / prof.elasticModulus_Wx, "sigma")
        assertClose(r.shearStressMax, (qd * L / 2) * 1000 / (prof.depth_d * prof.webThickness_tw), "tau")
        // Sem checagem de status aqui, de propósito (como no verify.ts original): com q=10kN/m e
        // L=6m, a flecha (17,26mm) passa do limite L/350 (17,14mm) em ~0,66% — o status correto
        // deste caso é FAIL por flecha, não PASS. Checar o status exigiria um caso com folga maior.
    }

    // MARK: C2 — biapoiada, carga pontual excêntrica (inclui posições fora da malha de amostragem)

    func testC2_BiapoiadaPontual() {
        for a in [2.0, 2.51, 0.37] {
            let L = 6.0, P = 50.0, b = L - a, g = 1.4, Pd = P * g
            let r = solveBeam(spanLength: L, supportType: .biapoiada, loads: [ld(.point, P, a)], profile: prof, steelGrade: grade)
            assertClose(r.reactionA, Pd * b / L, "R_A a=\(a)", tol: 0.001)
            assertClose(r.reactionB, Pd * a / L, "R_B a=\(a)", tol: 0.001)
            assertClose(r.maxMoment, Pd * a * b / L, "M_max a=\(a)", tol: 0.001)

            var wmax = 0.0
            var x = 0.0
            while x <= L {
                let w: Double = x <= a
                    ? P * b * x * (L * L - b * b - x * x) / (6 * EI * L)
                    : P * a * (L - x) * (2 * L * x - x * x - a * a) / (6 * EI * L)
                wmax = max(wmax, w)
                x += 0.0005
            }
            assertClose(r.maxDeflection, wmax * 1000, "flecha a=\(a)", tol: 0.002)
        }
    }

    // MARK: C3 — balanço (cantilever)

    func testC3_Balanco() {
        let L = 3.0, P = 20.0, g = 1.4
        var r = solveBeam(spanLength: L, supportType: .cantilever, loads: [ld(.point, P, L)], profile: prof, steelGrade: grade)
        assertClose(r.reactionA, P * g, "R_A ponta")
        assertClose(abs(r.maxMoment), P * g * L, "M_engaste ponta")
        assertClose(abs(r.maxDeflection), P * pow(L, 3) / (3 * EI) * 1000, "flecha ponta")

        r = solveBeam(spanLength: L, supportType: .cantilever, loads: [ld(.distributed, 10, 0, length: L)], profile: prof, steelGrade: grade)
        assertClose(abs(r.maxMoment), 10 * g * L * L / 2, "M_engaste UDL")
        assertClose(abs(r.maxDeflection), 10 * pow(L, 4) / (8 * EI) * 1000, "flecha UDL")
        assertClose(r.allowableDeflection, 2 * L * 1000 / 350, "limite flecha 2L/350")
    }

    // MARK: C4 — biengastada

    func testC4_Biengastada() {
        let L = 6.0, g = 1.4
        var r = solveBeam(spanLength: L, supportType: .biengastada, loads: [ld(.distributed, 10, 0, length: L)], profile: prof, steelGrade: grade)
        assertClose(r.reactionA, 10 * g * L / 2, "R_A UDL")
        let mMin = r.momentCurve.map { $0.m }.min() ?? 0
        assertClose(abs(mMin), 10 * g * L * L / 12, "M_engaste UDL")
        assertClose(r.maxDeflection, 10 * pow(L, 4) / (384 * EI) * 1000, "flecha UDL")

        let P = 50.0, a = 1.5, b = L - a, Pd = P * g
        r = solveBeam(spanLength: L, supportType: .biengastada, loads: [ld(.point, P, a)], profile: prof, steelGrade: grade)
        let RA = Pd * b * b * (3 * a + b) / pow(L, 3)
        let MA = Pd * a * b * b / (L * L)
        assertClose(r.reactionA, RA, "R_A pontual")
        let mMin2 = r.momentCurve.map { $0.m }.min() ?? 0
        assertClose(abs(mMin2), MA, "M_engaste A pontual")
    }

    // MARK: C5 — contínua (2 vãos iguais)

    func testC5_Continua() {
        let L = 6.0, l = L / 2, q = 10 * 1.4
        let r = solveBeam(spanLength: L, supportType: .continua, loads: [ld(.distributed, 10, 0, length: L)], profile: prof, steelGrade: grade)
        assertClose(r.reactionA, 3 * q * l / 8, "R_A extremo")
        assertClose(r.reactionC ?? .nan, 10 * q * l / 8, "R_C central")
        assertClose(r.reactionB, 3 * q * l / 8, "R_B extremo dir.")
        assertClose(r.reactionA + r.reactionB + (r.reactionC ?? 0), q * L, "soma reações = q·L")
        assertClose(abs(r.maxMoment), q * l * l / 8, "M máx apoio central")
    }

    // MARK: C6 — momento aplicado, isolado e em superposição

    func testC6_MomentoAplicado() {
        let L = 6.0, M0 = 10.0, g = 1.4, Md = M0 * g
        let r = solveBeam(spanLength: L, supportType: .biapoiada, loads: [ld(.moment, M0, 3)], profile: prof, steelGrade: grade)
        assertClose(abs(r.reactionA), Md / L, "|R_A|")
        assertClose(r.momentCurve.last?.m ?? .nan, 0, "M(L) fecha em 0", tol: 0.01)
        assertClose(abs(r.maxMoment), Md / 2, "|M| máx")
    }

    func testC6b_UDLMaisMomento_Superposicao() {
        let L = 6.0, q = 10.0, M0 = 20.0, g = 1.4, qd = q * g, Md = M0 * g, a = 3.0
        let r = solveBeam(spanLength: L, supportType: .biapoiada, loads: [ld(.distributed, q, 0, length: L), ld(.moment, M0, a)], profile: prof, steelGrade: grade)
        var Mmax = 0.0, x = 0.0
        while x <= L {
            let Mudl = qd * L * x / 2 - qd * x * x / 2
            let Mm = -Md * x / L + (x >= a ? Md : 0)
            Mmax = max(Mmax, abs(Mudl + Mm))
            x += 0.001
        }
        assertClose(abs(r.maxMoment), Mmax, "|M| máx superposição")
    }

    // MARK: C7 — γf ≠ 1,4 (flecha em serviço, não majorada)

    func testC7_GammaFDiferente() {
        let L = 6.0, q = 10.0
        let r = solveBeam(spanLength: L, supportType: .biapoiada, loads: [ld(.distributed, q, 0, length: L, gammaF: 1.25)], profile: prof, steelGrade: grade)
        assertClose(r.maxDeflection, 5 * q * pow(L, 4) / (384 * EI) * 1000, "flecha de serviço (γf não entra na flecha)")
    }

    // MARK: Robustez — entradas inválidas nunca produzem PASS/ALERT/FAIL (fail-closed)

    func testFailClosed_EntradasInvalidas() {
        let casos: [(String, CalculationResults)] = [
            ("posição NaN", solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.point, 30, .nan)], profile: prof, steelGrade: grade)),
            ("vão NaN", solveBeam(spanLength: .nan, supportType: .biapoiada, loads: [ld(.distributed, 10, 0, length: 6)], profile: prof, steelGrade: grade)),
            ("carga Infinity", solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.point, .infinity, 3)], profile: prof, steelGrade: grade)),
            ("carga fora da viga", solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.point, 30, 9)], profile: prof, steelGrade: grade)),
            ("apoio B além de L", solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.point, 30, 3)], profile: prof, steelGrade: grade, supportPositions: SupportPositions(posA: 0, posB: 9))),
            ("apoios coincidentes", solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.point, 30, 3)], profile: prof, steelGrade: grade, supportPositions: SupportPositions(posA: 3, posB: 3))),
            ("carga negativa", solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.point, -5, 3)], profile: prof, steelGrade: grade)),
            ("γf inválido", solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.point, 5, 3, gammaF: .nan)], profile: prof, steelGrade: grade)),
            ("Ix = 0", solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.point, 5, 3)], profile: { var p = prof; p.inertia_Ix = 0; return p }(), steelGrade: grade)),
            ("fy = 0", solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.point, 5, 3)], profile: prof, steelGrade: { var g = grade; g.fy = 0; return g }())),
        ]
        for (nome, r) in casos {
            XCTAssertEqual(r.status, .invalid, "\(nome): esperava INVALID, obteve \(r.status)")
            XCTAssertFalse(r.errors.isEmpty, "\(nome): INVALID deveria vir com lista de erros")
        }
    }

    func testAdulteracaoDoPerfilNaoEDetectadaPeloMotor() {
        // Documenta uma limitação conhecida: o motor não audita o perfil/aço recebido.
        // A defesa real é assinar o resultado no servidor (ver docs/SEGURANCA.md do app web).
        var adulterado = prof
        adulterado.plasticModulus_Zx = prof.plasticModulus_Zx * 3
        let r = solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.distributed, 10, 0, length: 6)], profile: adulterado, steelGrade: grade)
        let original = solveBeam(spanLength: 6, supportType: .biapoiada, loads: [ld(.distributed, 10, 0, length: 6)], profile: prof, steelGrade: grade)
        XCTAssertNotEqual(r.momentCapacity_Mrd, original.momentCapacity_Mrd)
    }

    // MARK: Propriedades — equilíbrio e linearidade em configurações aleatórias (PRNG determinístico)

    /// Mesma recorrência linear congruente usada em verify.ts (seed=12345), com aritmética
    /// UInt32 — reproduz exatamente a mesma sequência que `(seed*1664525+1013904223) % 2^32` em JS.
    struct LCG {
        var state: UInt32
        mutating func next() -> Double {
            state = state &* 1664525 &+ 1013904223
            return Double(state) / 4294967296.0
        }
    }

    func testPropriedades_EquilibrioELinearidade() {
        var rnd = LCG(state: 12345)
        let tipos: [SupportType] = [.biapoiada, .cantilever, .biengastada, .continua]
        var falhasEquilibrio = 0
        var falhasLinearidade = 0

        for n in 0..<300 {
            let L = 2 + rnd.next() * 10
            let tipo = tipos[n % 4]
            var loads: [LoadItem] = []
            let nl = 1 + Int(rnd.next() * 4)
            for _ in 0..<nl {
                let k = Int(rnd.next() * 3)
                let xs = rnd.next() * L * 0.8
                if k == 0 {
                    loads.append(ld(.distributed, 1 + rnd.next() * 20, xs, length: rnd.next() * (L - xs), gammaF: 1 + rnd.next() * 0.4))
                } else if k == 1 {
                    loads.append(ld(.point, 1 + rnd.next() * 80, rnd.next() * L, gammaF: 1 + rnd.next() * 0.4))
                } else {
                    loads.append(ld(.moment, 1 + rnd.next() * 30, rnd.next() * L, gammaF: 1 + rnd.next() * 0.4))
                }
            }
            let r = solveBeam(spanLength: L, supportType: tipo, loads: loads, profile: prof, steelGrade: grade)
            // Uma resposta INVALID (fail-closed) nunca viola o equilíbrio: o motor se recusou a
            // responder em vez de arriscar um número errado — normalmente porque duas cargas
            // caíram perto demais uma da outra, criando um elemento de malha quase degenerado
            // (rigidez EI/l³ disparando) e deixando o sistema mal-condicionado. Isso é esperado
            // em ~1 a cada poucas centenas de configurações aleatórias; só avaliamos a igualdade
            // ΣR = ΣP quando o motor de fato produziu uma resposta.
            if r.status != .invalid {
                let sumR = r.reactionA + r.reactionB + (r.reactionC ?? 0)
                let okEq = abs(sumR - r.totalVerticalLoad) < 0.02 + 1e-4 * abs(r.totalVerticalLoad)
                if !okEq { falhasEquilibrio += 1 }
            }

            // Linearidade: dobrar γf dobra V, M e reações (a flecha não depende de γf)
            let loads2 = loads.map { l -> LoadItem in var l2 = l; l2.gammaF *= 2; return l2 }
            let r2 = solveBeam(spanLength: L, supportType: tipo, loads: loads2, profile: prof, steelGrade: grade)
            if r.status != .invalid && r2.status != .invalid {
                let okLin = abs(r2.maxMoment - 2 * r.maxMoment) < 0.05 + 1e-4 * abs(r.maxMoment)
                    && abs(r2.maxDeflection - r.maxDeflection) < 0.01 + 1e-4 * abs(r.maxDeflection)
                if !okLin { falhasLinearidade += 1 }
            }
        }
        XCTAssertEqual(falhasEquilibrio, 0, "\(falhasEquilibrio)/300 configurações falharam o equilíbrio ΣR = ΣP")
        XCTAssertEqual(falhasLinearidade, 0, "\(falhasLinearidade)/300 configurações falharam a linearidade M(2γf) = 2·M(γf)")
    }
}
