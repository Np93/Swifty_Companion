import SwiftUI

struct ProfileView: View {
    let user: IntraUser

    // Cursus sélectionné (on stocke l’ID du cursus)
    @State private var selectedCursusId: Int?

    // MARK: - Derived data

    private var availableCursus: [CursusUser] {
        user.cursus_users.sorted { $0.cursus.name.localizedCaseInsensitiveCompare($1.cursus.name) == .orderedAscending }
    }

    private var defaultCursus: CursusUser? {
        // On préfère "42" si présent, sinon on prend le plus haut niveau
        user.cursus_users.first(where: { $0.cursus.name.lowercased() == "42" })
        ?? user.cursus_users.max(by: { $0.level < $1.level })
    }

    private var selectedCursus: CursusUser? {
        guard let id = selectedCursusId else { return defaultCursus }
        return user.cursus_users.first(where: { $0.cursus.id == id }) ?? defaultCursus
    }

    private var selectedLevelPercent: Double {
        let fractional = selectedCursus?.level.truncatingRemainder(dividingBy: 1.0) ?? 0.0
        return fractional * 100.0
    }

    private var displayedSkills: [Skill] {
        selectedCursus?.skills ?? []
    }

    private var displayedProjects: [ProjectUser] {
        guard let cursusId = selectedCursus?.cursus.id else { return user.projects_users }

        // Filtrage fiable si l’API renvoie cursus_ids
        let filtered = user.projects_users.filter { p in
            (p.cursus_ids ?? []).contains(cursusId)
        }

        // Si l’API ne renvoie pas cursus_ids, filtered sera vide -> fallback
        return filtered.isEmpty ? user.projects_users : filtered
    }

    // MARK: - UI

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                header

                cursusSelector

                GroupBox("Info") {
                    VStack(alignment: .leading, spacing: 8) {
                        infoRow("Login", user.login)
                        infoRow("Email", user.email ?? "N/A")
//                        infoRow("Mobile", user.phone ?? "N/A")
//                        infoRow("Location", user.location ?? "Unavailable")
                        infoRow("Wallet", user.wallet.map(String.init) ?? "N/A")
                        infoRow("Correction points", user.correction_point.map(String.init) ?? "N/A")

                        if let c = selectedCursus {
                            Divider().padding(.vertical, 6)
                            infoRow("Cursus", c.cursus.name)
                            infoRow("Level", String(format: "%.2f (%.0f%%)", c.level, selectedLevelPercent))
                        }
                    }
                }
                .tint(Theme.primary)

                GroupBox("Skills") {
                    if displayedSkills.isEmpty {
                        Text("No skills available.")
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(displayedSkills) { skill in
                                let percent = min((skill.level / 21.0) * 100.0, 100.0)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(skill.name).bold()
                                        Spacer()
                                        Text(String(format: "%.2f (%.0f%%)", skill.level, percent))
                                                                    .foregroundStyle(Theme.textSecondary)
                                    }
                                    ProgressView(value: min(skill.level / 21.0, 1.0))
                                        .tint(Theme.primary)
                                        .scaleEffect(x: 1, y: 1.25, anchor: .center)
                                        .animation(.easeInOut(duration: 0.4), value: skill.level)
                                }
                            }
                        }
                    }
                }
                .tint(Theme.primary)

                GroupBox("Projects") {
                    if displayedProjects.isEmpty {
                        Text("No projects available.")
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        let sorted = displayedProjects.sorted { ($0.final_mark ?? -1) > ($1.final_mark ?? -1) }

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(sorted) { p in
                                projectCard(p)
                            }
                        }
                    }
                }
                .tint(Theme.primary)
            }
            .padding()
            .frame(maxWidth: 720) // joli sur iPad
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(user.login)
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(
                colors: [Theme.primary.opacity(0.12), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            // Initialise la sélection au premier affichage
            if selectedCursusId == nil {
                selectedCursusId = defaultCursus?.cursus.id
            }
        }
    }

    // Components

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            AsyncImage(url: URL(string: user.image?.versions?.medium ?? user.image?.link ?? "")) { phase in
                switch phase {
                case .empty:
                    ProgressView().frame(width: 72, height: 72)
                case .success(let image):
                    image.resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            VStack(alignment: .leading) {
                Text(user.login).font(.title2).bold()
                Text(user.email ?? "N/A").foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private var cursusSelector: some View {
        GroupBox("Cursus selection") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableCursus, id: \.cursus.id) { c in
                        let isSelected = (selectedCursusId ?? defaultCursus?.cursus.id) == c.cursus.id

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCursusId = c.cursus.id
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(c.cursus.name)
                                    .font(.subheadline)
                                    .bold()

                                Text(String(format: "%.2f", c.level))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(isSelected ? Theme.primary.opacity(0.18) : Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? Theme.primary.opacity(0.55) : Theme.textSecondary.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .tint(Theme.primary)
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(key):").bold()
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    private enum ProjectState {
        case validated           // validated? == true
        case failed              // validated? == false
        case waitingCorrection   // waiting_for_correction
        case inEvaluation        // evaluating / being corrected
        case groupClosed         // group closed
        case inProgress          // in progress / creating / searching
        case unknown             // fallback

        var label: String {
            switch self {
            case .validated: return "Validated"
            case .failed: return "Failed"
            case .waitingCorrection: return "Waiting for correction"
            case .inEvaluation: return "In evaluation"
            case .groupClosed: return "Group closed"
            case .inProgress: return "In progress"
            case .unknown: return "Unknown"
            }
        }

        var icon: String {
            switch self {
            case .validated: return "checkmark.seal.fill"
            case .failed: return "xmark.octagon.fill"
            case .waitingCorrection: return "clock.badge.exclamationmark"
            case .inEvaluation: return "magnifyingglass.circle.fill"
            case .groupClosed: return "lock.fill"
            case .inProgress: return "hammer.fill"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    private func projectState(for p: ProjectUser) -> ProjectState {
        // 1) vérité absolue si l’API le donne
        if p.validated == true { return .validated }
        if p.validated == false { return .failed }

        // 2) sinon on classe par status
        let s = (p.status ?? "").lowercased()

        // états fréquents côté 42
        if s == "waiting_for_correction" { return .waitingCorrection }

        // Selon les comptes/années, on peut voir des statuts proches
        if s.contains("correction") || s.contains("correct") || s.contains("evaluat") {
            return .inEvaluation
        }

        if s.contains("group") && s.contains("closed") {
            return .groupClosed
        }

        if s.contains("in_progress") || s.contains("creating") || s.contains("searching") {
            return .inProgress
        }

        return .unknown
    }

    private func projectTheme(for state: ProjectState) -> (tint: Color, background: Color, border: Color) {
        switch state {
        case .validated:
            return (Theme.success, Theme.success.opacity(0.10), Theme.success.opacity(0.25))

        case .failed:
            return (Theme.danger, Theme.danger.opacity(0.10), Theme.danger.opacity(0.25))

        case .waitingCorrection:
            return (Theme.warning, Theme.warning.opacity(0.12), Theme.warning.opacity(0.28))

        case .inEvaluation:
            return (Theme.secondary, Theme.secondary.opacity(0.10), Theme.secondary.opacity(0.22))

        case .groupClosed:
            return (Theme.textSecondary, Theme.textSecondary.opacity(0.08), Theme.textSecondary.opacity(0.22))

        case .inProgress:
            return (Theme.textSecondary, Theme.card, Theme.textSecondary.opacity(0.15))

        case .unknown:
            return (Theme.textSecondary, Theme.card, Theme.textSecondary.opacity(0.15))
        }
    }

    private func projectBadge(_ state: ProjectState, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: state.icon)
                .font(.caption)
            Text(state.label)
                .font(.caption)
                .bold()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(tint.opacity(0.12))
        .foregroundStyle(tint)
        .clipShape(Capsule())
    }
    
    private func projectCard(_ p: ProjectUser) -> some View {
        let mark = p.final_mark ?? 0
        let maxMark: Int = (mark > 100) ? 125 : 100
        let progress = Double(mark) / Double(maxMark)

        let state = projectState(for: p)
        let theme = projectTheme(for: state)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.project.name).bold()

                    // status lisible
                    if let status = p.status, !status.isEmpty {
                        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("N/A")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer()

                projectBadge(state, tint: theme.tint)
            }

            HStack {
                Text("Mark: \(p.final_mark != nil ? "\(mark)/\(maxMark)" : "N/A")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()

                // petit % pour lecture rapide
                if p.final_mark != nil {
                    Text(String(format: "%.0f%%", min(max(progress, 0), 1) * 100))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            ProgressView(value: min(max(progress, 0), 1))
                .tint(theme.tint)
                .scaleEffect(x: 1, y: 1.35, anchor: .center)
                .animation(.easeInOut(duration: 0.6), value: mark)
        }
        .padding(12)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}
