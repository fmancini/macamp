import Foundation
import Testing
@testable import WampKit

private func tracks(_ n: Int) -> [Track] {
    (1...n).map { Track(url: URL(fileURLWithPath: "/tmp/t\($0).mp3")) }
}

@Test func firstAppendedTrackBecomesCurrent() {
    var q = QueueState()
    let t = tracks(3)
    q.append(t)
    #expect(q.currentID == t[0].id)
}

@Test func advanceWalksTheQueueAndStopsAtTheEnd() {
    var q = QueueState()
    let t = tracks(3)
    q.append(t)
    #expect(q.advance(auto: true) == t[1].id)
    #expect(q.advance(auto: true) == t[2].id)
    #expect(q.advance(auto: true) == nil)
    #expect(q.currentID == t[2].id)
}

@Test func repeatAllWrapsAround() {
    var q = QueueState()
    let t = tracks(2)
    q.append(t)
    q.repeatMode = .all
    q.advance(auto: true)
    #expect(q.advance(auto: true) == t[0].id)
}

@Test func repeatOneRepeatsOnlyWhenTheTrackEndsByItself() {
    var q = QueueState()
    let t = tracks(3)
    q.append(t)
    q.repeatMode = .one
    #expect(q.advance(auto: true) == t[0].id)
    #expect(q.currentID == t[0].id)
    #expect(q.advance(auto: false) == t[1].id)
}

@Test func shufflePlaysEveryTrackOnceBeforeRepeating() {
    var q = QueueState()
    let t = tracks(6)
    q.append(t)
    q.shuffle = true
    var played: Set<UUID> = [q.currentID!]
    var rng = SystemRandomNumberGenerator()
    for _ in 0..<5 {
        let next = q.advance(auto: true, using: &rng)!
        #expect(!played.contains(next))
        played.insert(next)
    }
    #expect(played.count == 6)
    #expect(q.advance(auto: true, using: &rng) == nil)
}

@Test func goBackStepsToThePreviousTrack() {
    var q = QueueState()
    let t = tracks(3)
    q.append(t)
    q.advance(auto: false)
    q.advance(auto: false)
    #expect(q.goBack() == t[1].id)
    #expect(q.goBack() == t[0].id)
    #expect(q.goBack() == t[0].id)
}

@Test func removingTheCurrentTrackMovesToTheNextOne() {
    var q = QueueState()
    let t = tracks(3)
    q.append(t)
    q.remove(ids: [t[0].id])
    #expect(q.currentID == t[1].id)
    q.remove(ids: [t[1].id, t[2].id])
    #expect(q.currentID == nil)
    #expect(q.isEmpty)
}

@Test func moveReordersWithoutChangingTheCurrentTrack() {
    var q = QueueState()
    let t = tracks(4)
    q.append(t)
    q.move(from: IndexSet(integer: 0), to: 3)
    #expect(q.tracks.map(\.id) == [t[1].id, t[2].id, t[0].id, t[3].id])
    #expect(q.currentID == t[0].id)
}

@Test func queueSurvivesASaveAndLoad() throws {
    var q = QueueState()
    q.append(tracks(3))
    q.shuffle = true
    q.repeatMode = .all
    let url = FileManager.default.temporaryDirectory.appending(path: "wamp-queue-test.json")
    QueueStore.save(q, to: url)
    #expect(QueueStore.load(from: url) == q)
    try? FileManager.default.removeItem(at: url)
}

@Test func clockFormatsMinutesAndHours() {
    #expect(Track.clock(0) == "0:00")
    #expect(Track.clock(225) == "3:45")
    #expect(Track.clock(3723) == "1:02:03")
    #expect(Track.clock(-4) == "0:00")
}
