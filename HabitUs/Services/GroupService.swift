import Foundation
import HabitCore
import Supabase

// Create, join, accept, start and finish groups (R4 to R8). Area A.
// STUBS: replace each body with the real Supabase call.

/// One card on Home (SPEC section 4, Home).
struct GameCard: Identifiable {
    var group: HabitGroup
    var myStatus: MembershipStatus
    var isOwner: Bool
    var memberCount: Int
    var openRequests: Int

    var id: UUID { group.id }
}

enum GroupService {
    /// R4: the creator becomes owner, signs the contract and gets an invite code.
    static func createGroup(name: String, habit: String, target: Int, period: Period, endOn: Date?,
                            rulesText: String, signature: String) async throws -> HabitGroup {
        throw notBuiltYet
    }

    /// R5: calls the database function join_by_code, which creates a pending request.
    static func requestToJoin(code: String, signature: String) async throws {
        throw notBuiltYet
    }

    /// R6: owner only. Declined is final.
    static func decide(membershipId: UUID, accept: Bool) async throws {
        throw notBuiltYet
    }

    /// R7: owner only, at least 3 accepted members, declines all open requests.
    static func start(groupId: UUID) async throws {
        throw notBuiltYet
    }

    /// R8: owner only, sets ended_early_at.
    static func finish(groupId: UUID) async throws {
        throw notBuiltYet
    }

    static func myGames() async throws -> [GameCard] {
        throw notBuiltYet
    }

    static func members(groupId: UUID) async throws -> [Member] {
        throw notBuiltYet
    }
}
