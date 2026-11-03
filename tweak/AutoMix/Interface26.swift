// The slice of Apple's SonicKit the planner helper needs, written by hand.
//
// DRAFT: nobody on this project has seen the framework's own interface. Everything below is the shape the
// symbols in the 1.0.1 build spell out; the compiler on a Mac is what turns it into the real thing. Each line
// says which symbol it came from, so a mismatch can be found quickly.
//
//   TransitionPlannerV10transition4from2to8criterias6ResultOyAA0E0VAC13FailureReasonOGAC4SongV_ApC8CriteriaVtKF
//   TransitionPlannerV13ConfigurationV7defaultAEvgZ
//   TransitionPlannerV4SongV2id8duration8analysis7context...
//   Transition.V10Complexity / V8DSPGraph / V17SongPlaybackState / V19TimeStretchingState
//   TransitionPlannerV8CriteriaV17IncomingPlacementO / OutgoingPlacementO (Early/LateConstraint)
//
// On iOS 26 the framework is `SonicKit_MusicKit_Packages`; below it, `SonicKit_MusicKit`, and the types differ
// (the build's own string: "this system's planner types differ from Interface27.swift"). Two targets, one
// interface each.
import Foundation

public struct TransitionPlanner {
    public struct Configuration {
        public static let `default`: Configuration = Configuration()
        public init() {}
    }

    public struct Song {
        public struct ID: Hashable {
            public let rawValue: String
            public init(_ rawValue: String) { self.rawValue = rawValue }
        }
        public struct Context {}
        // `…AnalysisOSeAAMc`: the analysis is Decodable, so it can be fed to the planner as JSON from this side
        // once its shape is known.
        public enum Analysis: Decodable {}

        public let id: ID
        public let duration: Double?
        public let analysis: Analysis?
        public let context: Context?

        public init(id: ID, duration: Double?, analysis: Analysis?, context: Context?) {
            self.id = id
            self.duration = duration
            self.analysis = analysis
            self.context = context
        }
    }

    public struct Criteria {
        public enum OutgoingPlacement { public enum EarlyConstraint {}; public enum LateConstraint {} }
        public enum IncomingPlacement { public enum EarlyConstraint {}; public enum LateConstraint {} }
        public static let `default` = Criteria()
        public init() {}
    }

    public enum FailureReason: Error { case unavailable }

    public let configuration: Configuration
    public init(configuration: Configuration) { self.configuration = configuration }

    // The one call worth having: what the transition is, or why there is none.
    public func transition(from: Song, to: Song, criterias: Criteria) -> Result<Transition, FailureReason> {
        .failure(.unavailable)   // replaced by the framework's own implementation when this links
    }
}

// `…TransitionVSEAAMc`: Encodable, so the plan is JSON rather than a printed dump.
public struct Transition: Encodable {
    public enum Complexity {}
    public struct DSPGraph {}
    public struct SongPlaybackState {}
    public struct TimeStretchingState {}
    public enum SchedulingPolicy {}
}

// `…StretchedSongTimeVMn`: a value type of its own, named in the symbols and worth declaring when it is needed.
public struct StretchedSongTime {}
