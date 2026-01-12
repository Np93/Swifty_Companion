import Foundation

struct TokenResponse: Decodable, Sendable, Hashable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
}

struct IntraUser: Decodable, Identifiable, Hashable {
    let login: String
    let email: String?
    let phone: String?
    let location: String?
    let wallet: Int?
    let correction_point: Int?
    let cursus_users: [CursusUser]
    let projects_users: [ProjectUser]
    let image: UserImage?

    var id: String { login }
}

struct UserImage: Decodable, Hashable {
    let link: String?
    let versions: ImageVersions?
}

struct ImageVersions: Decodable, Hashable {
    let large: String?
    let medium: String?
    let small: String?
    let micro: String?
}

struct CursusUser: Decodable, Hashable {
    let level: Double
    let skills: [Skill]
    let cursus: CursusInfo
}

struct CursusInfo: Decodable, Hashable {
    let id: Int
    let name: String
}

struct Skill: Decodable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let level: Double
}

struct ProjectUser: Decodable, Identifiable, Hashable {
    let id: Int
    let final_mark: Int?
    let status: String?
    let validated: Bool?
    let cursus_ids: [Int]?
    let project: Project

    enum CodingKeys: String, CodingKey {
        case id
        case final_mark
        case status
        case validated = "validated?"
        case cursus_ids
        case project
    }
}

struct Project: Decodable, Hashable {
    let name: String
}
