import SwiftUI

struct SessionDetailWindowView: View {
    let sessionId: String?
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        if let sessionId,
           let session = sessionStore.sessions.first(where: { $0.id == sessionId })
        {
            SessionDetailView(session: session)
        } else {
            Text("Session not found")
                .frame(width: 400, height: 300)
        }
    }
}
