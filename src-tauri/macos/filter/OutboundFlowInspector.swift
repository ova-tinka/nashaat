import Foundation

enum OutboundInspectionKind: Equatable {
  case tls
  case http
}

enum OutboundInspectionResult: Equatable {
  case need(peekBytes: Int)
  case host(String, bufferedBytes: Int)
  case unknown
}

/// Thread-safe, bounded per-flow accumulator for incremental outbound bytes
/// delivered by `NEFilterDataProvider.handleOutboundData(from:readBytesStartOffset:readBytes:)`.
final class OutboundFlowInspector {
  static let maxTrackedFlows = 1_024

  private struct Entry {
    let kind: OutboundInspectionKind
    var data: Data
    var sequence: UInt64
  }

  private let lock = NSLock()
  private var buffers: [UUID: Entry] = [:]
  private var nextSequence: UInt64 = 0

  var trackedFlowCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return buffers.count
  }

  func begin(flowID: UUID, kind: OutboundInspectionKind) -> Int {
    let limit = kind == .tls ? TLSHostname.maximum : HTTPHostname.maximum
    lock.lock()
    defer { lock.unlock() }
    if buffers[flowID] == nil && buffers.count >= Self.maxTrackedFlows {
      if let oldestKey = buffers.min(by: { $0.value.sequence < $1.value.sequence })?.key {
        buffers.removeValue(forKey: oldestKey)
      }
    }
    nextSequence &+= 1
    buffers[flowID] = Entry(kind: kind, data: Data(), sequence: nextSequence)
    return limit
  }

  func forget(flowID: UUID) {
    lock.lock()
    buffers.removeValue(forKey: flowID)
    lock.unlock()
  }

  func feed(flowID: UUID, kind: OutboundInspectionKind, offset: Int, chunk: Data) -> OutboundInspectionResult {
    let limit = kind == .tls ? TLSHostname.maximum : HTTPHostname.maximum
    guard offset >= 0 else {
      forget(flowID: flowID)
      return .unknown
    }

    let snapshot: Data
    lock.lock()
    var entry = buffers[flowID]
    if entry == nil {
      guard offset == 0 else {
        lock.unlock()
        return .unknown
      }
      if buffers.count >= Self.maxTrackedFlows,
         let oldestKey = buffers.min(by: { $0.value.sequence < $1.value.sequence })?.key {
        buffers.removeValue(forKey: oldestKey)
      }
      nextSequence &+= 1
      entry = Entry(kind: kind, data: Data(), sequence: nextSequence)
    }
    guard var current = entry, current.kind == kind else {
      buffers.removeValue(forKey: flowID)
      lock.unlock()
      return .unknown
    }

    if offset == current.data.count {
      current.data.append(chunk)
    } else if offset == 0 && chunk.count > current.data.count {
      current.data = chunk
    } else if offset < current.data.count {
      let overlapEnd = offset + chunk.count
      if overlapEnd > current.data.count {
        let newStart = current.data.count - offset
        current.data.append(chunk.dropFirst(newStart))
      } else if current.data.count >= limit {
        buffers.removeValue(forKey: flowID)
        lock.unlock()
        return .unknown
      }
    } else {
      buffers.removeValue(forKey: flowID)
      lock.unlock()
      return .unknown
    }

    if current.data.count > limit {
      current.data = Data(current.data.prefix(limit))
    }
    buffers[flowID] = current
    snapshot = current.data
    lock.unlock()

    switch kind {
    case .tls:
      switch TLSHostname.parse(snapshot) {
      case .host(let host):
        forget(flowID: flowID)
        return .host(host, bufferedBytes: snapshot.count)
      case .unknown:
        forget(flowID: flowID)
        return .unknown
      case .need(let totalNeeded):
        if snapshot.count >= limit || totalNeeded > limit {
          forget(flowID: flowID)
          return .unknown
        }
        return .need(peekBytes: min(max(totalNeeded, 1), limit))
      }
    case .http:
      switch HTTPHostname.parse(snapshot) {
      case .host(let host):
        forget(flowID: flowID)
        return .host(host, bufferedBytes: snapshot.count)
      case .unknown:
        forget(flowID: flowID)
        return .unknown
      case .need(let totalNeeded):
        if snapshot.count >= limit || totalNeeded > limit {
          forget(flowID: flowID)
          return .unknown
        }
        return .need(peekBytes: min(max(totalNeeded, 1), limit))
      }
    }
  }
}
