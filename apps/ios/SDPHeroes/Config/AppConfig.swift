//
//  AppConfig.swift
//  SDP Heroes
//
//  Reads Supabase + API config from Info.plist, which is populated at
//  build time by xcconfig variable substitution. NEVER hardcode keys
//  in Swift source. NEVER read from a bundled JSON. The xcconfig
//  files live at ../Config/Debug.xcconfig and Release.xcconfig and
//  are git-ignored; the .template versions are committed.
//
//  Add these entries to Info.plist (with $(SUPABASE_URL) etc as the
//  raw value):
//    SUPABASE_URL    -> $(SUPABASE_URL)
//    SUPABASE_ANON_KEY -> $(SUPABASE_ANON_KEY)
//    API_BASE_URL    -> $(API_BASE_URL)
//

import Foundation

enum AppConfigError: Error {
    case missingKey(String)
    case malformedURL(String)
}

struct AppConfig {
    let supabaseURL: URL
    let supabaseAnonKey: String
    let apiBaseURL: URL

    static let shared: AppConfig = {
        do {
            return try AppConfig.load()
        } catch {
            fatalError("AppConfig load failed: \(error). Did you copy the xcconfig template + fill in real values?")
        }
    }()

    private static func load() throws -> AppConfig {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let urlStr = info["SUPABASE_URL"] as? String, !urlStr.isEmpty else {
            throw AppConfigError.missingKey("SUPABASE_URL")
        }
        guard let url = URL(string: urlStr) else {
            throw AppConfigError.malformedURL(urlStr)
        }
        guard let key = info["SUPABASE_ANON_KEY"] as? String, !key.isEmpty else {
            throw AppConfigError.missingKey("SUPABASE_ANON_KEY")
        }
        guard let apiStr = info["API_BASE_URL"] as? String, !apiStr.isEmpty else {
            throw AppConfigError.missingKey("API_BASE_URL")
        }
        guard let apiURL = URL(string: apiStr) else {
            throw AppConfigError.malformedURL(apiStr)
        }
        return AppConfig(
            supabaseURL: url,
            supabaseAnonKey: key,
            apiBaseURL: apiURL
        )
    }
}
