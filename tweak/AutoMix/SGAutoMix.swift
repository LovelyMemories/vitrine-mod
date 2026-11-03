// The AutoMix planner helper: a small Swift library that asks Apple's SonicKit where one song should give way
// to the next, and hands the answer back to the tweak as JSON.
//
// It is loaded by Shared/AutoMix/AutoMix.m with dlopen and one symbol, SGAutoMixPlan, and is never linked into
// the tweak: a system without SonicKit simply has no planner. See docs/automix-sonickit.md.
//
// DRAFT. This file is not part of the tweak's build (tweak/Makefile only reads tweak/Sources). It compiles on a
// Mac against the iOS 26 SDK once Interface26.swift has been completed against the real private framework --
// the type names below are the ones read out of the 1.0.1 build's symbols, not a header anyone has seen.
import Foundation
import SonicKit_MusicKit_Packages

// The tweak's C side: three JSON documents in, one JSON document out, which the caller frees.
@_cdecl("SGAutoMixPlan")
public func SGAutoMixPlan(_ outgoingJSON: UnsafePointer<CChar>?,
                          _ incomingJSON: UnsafePointer<CChar>?,
                          _ criteriaJSON: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
    guard let outgoingJSON, let incomingJSON else { return nil }
    guard let outgoing = song(fromJSON: outgoingJSON), let incoming = song(fromJSON: incomingJSON) else {
        return strdup(#"{"error":"a song could not be read"}"#)
    }

    let criteria = criteriaJSON.flatMap { json in
        (try? JSONDecoder().decode(TransitionPlanner.Criteria.self, from: Data(bytes: json, count: strlen(json))))
    } ?? .default

    // Configuration.default is what Apple Music itself plans with; a variant of it would go here.
    let planner = TransitionPlanner(configuration: .default)
    switch planner.transition(from: outgoing, to: incoming, criterias: criteria) {
    case .success(let transition):
        return strdup(text(of: transition))
    case .failure(let reason):
        return strdup(#"{"error":"\#(reason)"}"#)
    }
}

/// A song as the planner takes it: an id, a length, and the analysis it may or may not have. Without analysis it
/// plans from the length and the criteria alone, which is a schedule rather than a musical transition.
private func song(fromJSON pointer: UnsafePointer<CChar>) -> TransitionPlanner.Song? {
    let data = Data(bytes: pointer, count: strlen(pointer))
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    guard let identifier = object["id"] as? String, let duration = object["duration"] as? Double else { return nil }
    // TODO: the analysis the planner wants, once its shape is known. nil is accepted and plans blind.
    return TransitionPlanner.Song(id: TransitionPlanner.Song.ID(identifier),
                                  duration: duration,
                                  analysis: nil,
                                  context: nil)
}

/// The planner's answer as text for the tweak. `dump` is what the 1.0.1 build appears to return as well; if the
/// real type is Encodable, `JSONEncoder` is the cleaner way and should replace this.
private func text(of transition: Transition) -> String {
    var out = ""
    dump(transition, to: &out)
    return out
}
