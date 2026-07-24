import Foundation
import Supabase

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://evcuvxmxqunpaeguigoy.supabase.co")!,
        supabaseKey: "sb_publishable_aQz7wjQleqYuv8tVC4jW4w_CGB86hNY",
        options: SupabaseClientOptions(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}
