// QueueMode mirrors pi-mono's message queue behavior: send queued user messages
// either one at a time per turn, or all queued together before the next turn.
public enum QueueMode: String, Sendable {
    case oneAtATime = "one-at-a-time"
    case all = "all"
}

