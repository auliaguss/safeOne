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
        client = SupabaseClient(
            supabaseURL: URL(string: "https://kdknxnyxuxzamsaberzz.supabase.co")!,
            supabaseKey: "sb_publishable_JNXMNU3L-Aslx3EKaaxivw_tBWqzGpf"
        )
    }
}
