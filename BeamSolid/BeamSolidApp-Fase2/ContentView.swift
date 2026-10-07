/**
 * BeamSolid — Fase 2: interface mínima em SwiftUI.
 * Escolher perfil/aço, lançar cargas, calcular e ver o resultado. Usa o BeamSolidEngine (Fase 1)
 * como dependência — todo o cálculo acontece lá; esta tela só coleta entradas e mostra a saída.
 */
import SwiftUI
import Charts
import BeamSolidEngine

/// Representação editável de uma carga na tela (texto livre nos campos, convertido para Double
/// só na hora de calcular — assim o usuário pode digitar "1,4" ou apagar o campo sem travar a UI).
struct EditableLoad: Identifiable {
    let id = UUID()
    var type: LoadType = .distributed
    var valueText: String = "10"
    var positionText: String = "0"
    var lengthText: String = ""
    var direction: LoadDirection = .down
    var gammaFText: String = "1.4"
}

private func parseNumber(_ s: String) -> Double? {
    let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    return t.isEmpty ? nil : Double(t)
}

struct ContentView: View {
    @State private var supportType: SupportType = .biapoiada
    @State private var spanText: String = "6"
    @State private var profileId: String = DEFAULT_PROFILE.id
    @State private var gradeIndex: Int = 1 // A572 Gr 50
    @State private var loads: [EditableLoad] = [EditableLoad()]
    @State private var result: CalculationResults?

    private var selectedProfile: SteelProfile {
        STEEL_PROFILES.first(where: { $0.id == profileId }) ?? DEFAULT_PROFILE
    }
    private var selectedGrade: SteelGrade {
        STEEL_GRADES.indices.contains(gradeIndex) ? STEEL_GRADES[gradeIndex] : STEEL_GRADES[0]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Viga") {
                    Picker("Tipo de apoio", selection: $supportType) {
                        Text("Biapoiada").tag(SupportType.biapoiada)
                        Text("Balanço").tag(SupportType.cantilever)
                        Text("Biengastada").tag(SupportType.biengastada)
                        Text("Contínua (2 vãos)").tag(SupportType.continua)
                    }
                    HStack {
                        Text("Vão L (m)")
                        Spacer()
                        TextField("6.0", text: $spanText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Material") {
                    Picker("Perfil", selection: $profileId) {
                        ForEach(STEEL_PROFILES, id: \.id) { p in
                            Text(p.designation).tag(p.id)
                        }
                    }
                    Picker("Aço", selection: $gradeIndex) {
                        ForEach(Array(STEEL_GRADES.enumerated()), id: \.offset) { i, g in
                            Text(g.name).tag(i)
                        }
                    }
                }

                Section("Cargas") {
                    ForEach($loads) { $load in
                        LoadEditorRow(load: $load)
                    }
                    .onDelete { idx in loads.remove(atOffsets: idx) }
                    Button {
                        loads.append(EditableLoad())
                    } label: {
                        Label("Adicionar carga", systemImage: "plus.circle")
                    }
                }

                Section {
                    Button("Calcular") { calcular() }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fontWeight(.semibold)
                }

                if let r = result {
                    ResultsSection(result: r)
                    if r.status != .invalid {
                        DiagramsSection(result: r)
                    }
                }
            }
            .navigationTitle("BeamSolid")
        }
    }

    private func calcular() {
        let L = parseNumber(spanText) ?? .nan
        let items: [LoadItem] = loads.map { l in
            LoadItem(
                type: l.type,
                value: parseNumber(l.valueText) ?? .nan,
                positionX: parseNumber(l.positionText) ?? .nan,
                length: l.type == .distributed ? parseNumber(l.lengthText) : nil,
                direction: l.direction,
                gammaF: parseNumber(l.gammaFText) ?? .nan
            )
        }
        result = solveBeam(
            spanLength: L, supportType: supportType, loads: items,
            profile: selectedProfile, steelGrade: selectedGrade
        )
    }
}

private struct LoadEditorRow: View {
    @Binding var load: EditableLoad

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Tipo", selection: $load.type) {
                Text("Distribuída (kN/m)").tag(LoadType.distributed)
                Text("Pontual (kN)").tag(LoadType.point)
                Text("Momento (kN·m)").tag(LoadType.moment)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Valor")
                Spacer()
                TextField("0", text: $load.valueText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Posição x (m)")
                Spacer()
                TextField("0", text: $load.positionText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            if load.type == .distributed {
                HStack {
                    Text("Comprimento (m)")
                    Spacer()
                    TextField("até o fim da viga", text: $load.lengthText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            HStack {
                Text("Coef. γf")
                Spacer()
                TextField("1.4", text: $load.gammaFText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            Picker("Direção", selection: $load.direction) {
                Text("Para baixo").tag(LoadDirection.down)
                Text("Para cima").tag(LoadDirection.up)
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}

private struct ResultsSection: View {
    let result: CalculationResults

    private var statusColor: Color {
        switch result.status {
        case .pass: return .green
        case .alert: return .orange
        case .fail: return .red
        case .invalid: return .red
        case .none: return .gray
        }
    }
    private var statusLabel: String {
        switch result.status {
        case .pass: return "OK — dentro dos limites"
        case .alert: return "Atenção — próximo do limite"
        case .fail: return "Reprovado — excede os limites"
        case .invalid: return "Não foi possível calcular"
        case .none: return "Sem cargas lançadas"
        }
    }

    var body: some View {
        Section("Resultado") {
            HStack {
                Circle().fill(statusColor).frame(width: 10, height: 10)
                Text(statusLabel).fontWeight(.semibold)
            }
            if result.status == .invalid {
                ForEach(result.errors, id: \.self) { e in
                    Text(e).font(.caption).foregroundStyle(.red)
                }
            } else {
                row("Reação A", result.reactionA, "kN")
                row("Reação B", result.reactionB, "kN")
                if let rc = result.reactionC { row("Reação C (apoio central)", rc, "kN") }
                row("Momento máx.", result.maxMoment, "kN·m")
                row("Cortante máx. (+)", result.maxShearPos, "kN")
                row("Cortante máx. (−)", result.maxShearNeg, "kN")
                row("Flecha máx.", result.maxDeflection, "mm")
                row("Flecha admissível", result.allowableDeflection, "mm")
                row("Utilização à flexão", result.momentRatio, "%")
                row("Utilização ao cisalhamento", result.shearRatio, "%")
                row("Utilização da flecha", result.deflectionRatio, "%")
            }
            if !result.warnings.isEmpty {
                ForEach(result.warnings, id: \.self) { w in
                    Text(w).font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }

    private func row(_ label: String, _ value: Double, _ unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.2f %@", value, unit)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Diagramas (cortante, momento, flecha)

/// Ponto de um diagrama. `Identifiable` por exigência do inicializador mais simples do Charts.
private struct ChartPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
}

/// Um diagrama (linha + área sob a curva + linha de referência em y=0), com o pico destacado.
private struct SingleDiagram: View {
    let title: String
    let unit: String
    let points: [ChartPoint]
    let color: Color

    private var peak: ChartPoint? {
        points.max(by: { abs($0.y) < abs($1.y) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Spacer()
                if let p = peak {
                    Text(String(format: "pico: %.2f %@ em x=%.2f m", p.y, unit, p.x))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Chart(points) { p in
                AreaMark(x: .value("x (m)", p.x), y: .value(unit, p.y))
                    .foregroundStyle(color.opacity(0.18))
                LineMark(x: .value("x (m)", p.x), y: .value(unit, p.y))
                    .foregroundStyle(color)
                    .interpolationMethod(.linear)
                RuleMark(y: .value("zero", 0))
                    .foregroundStyle(.gray.opacity(0.5))
            }
            .chartXAxisLabel("x (m)")
            .chartYAxisLabel(unit)
            .frame(height: 150)
        }
        .padding(.vertical, 4)
    }
}

/// As três curvas já vêm prontas do motor (`shearCurve`, `momentCurve`, `deflectionCurve`) — esta
/// seção só desenha o que o `solveBeam` calculou, sem repetir nenhuma conta.
private struct DiagramsSection: View {
    let result: CalculationResults

    var body: some View {
        Section("Diagramas") {
            SingleDiagram(
                title: "Cortante (V)", unit: "kN", color: .blue,
                points: result.shearCurve.map { ChartPoint(x: $0.x, y: $0.v) }
            )
            SingleDiagram(
                title: "Momento fletor (M)", unit: "kN·m", color: .orange,
                points: result.momentCurve.map { ChartPoint(x: $0.x, y: $0.m) }
            )
            SingleDiagram(
                // Flecha negada na plotagem: convenção do motor é positivo = para baixo, então
                // invertemos o sinal aqui para a curva aparecer "afundando" visualmente, como
                // numa viga fletida de verdade — sem mexer no dado original do motor.
                title: "Flecha (visual: positivo para baixo)", unit: "mm", color: .green,
                points: result.deflectionCurve.map { ChartPoint(x: $0.x, y: -$0.d) }
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
