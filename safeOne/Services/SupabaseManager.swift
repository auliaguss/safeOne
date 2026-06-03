//
//  SupabaseManager.swift
//  safeOne
//
//  Created by Hercio Venceslau Silla on 03/06/26.
//
import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let supabaseURLString =
            Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
            ?? UserDefaults.standard.string(forKey: "SUPABASE_URL")
            ?? "https://kdknxnyxuxzamsaberzz.supabase.co"

        let supabaseAnonKey =
            Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
            ?? UserDefaults.standard.string(forKey: "SUPABASE_ANON_KEY")
            ?? "sb_publishable_JNXMNU3L-Aslx3EKaaxivw_tBWqzGpf"

        client = SupabaseClient(
            supabaseURL: URL(string: supabaseURLString)!,
            supabaseKey: supabaseAnonKey
        )
    }
}
