//
//  Recorder.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 10/4/2022.
//

import Foundation
import MetalPetal
import VideoIO

struct State {
  var isRecording: Bool = false
}

class Recorder {
  private let logger = Logger(subsystem: Config.shared.subsystem, category: "Recorder")
  
  private let queue: DispatchQueue = DispatchQueue(label: "recorder.queue")
  
  private let stateLock = MTILockCreate()
  
  @Published private var stateChangeCount: Int = 0
  private var _state: State = State()
  private(set) var state: State {
    get {
      stateLock.lock()
      defer {
        stateLock.unlock()
      }
      return _state
    }
    set {
      stateLock.lock()
      defer {
        stateLock.unlock()
        
        //ensure that the state update happens on main thread.
//        dispatchPrecondition(condition: .onQueue(.main))
        stateChangeCount += 1
      }
      _state = newValue
    }
  }
  
  private var recorder: MovieRecorder?
  
  static let instance = Recorder()
  private init() {
  }
  
  func startRecording() throws {
    let date = Date()
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    let filename = formatter.string(from: date).replacingOccurrences(of: ":", with: "_")
    
    let url = Config.shared.recordingDirectory.appendingPathComponent("\(filename).mp4")
    // record audio when permission is given
    let recorder = try MovieRecorder(url: url, configuration: MovieRecorder.Configuration(hasAudio: true))
    state.isRecording = true
    queue.async {
      self.recorder = recorder
    }
  }
  
  func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
    if self.state.isRecording {
      if let recorder = recorder {
        recorder.stopRecording(completion: { error in
          self.state.isRecording = false
          if let error = error {
            completion(.failure(error))
          } else {
            completion(.success(recorder.url))
          }
        })
        queue.async {
          self.recorder = nil
        }
      }
    }
  }
  
  func record(_ sampleBuffer: CMSampleBuffer) throws {
    if self.state.isRecording {
      try self.recorder?.appendSampleBuffer(sampleBuffer)
    }
  }
}

extension ISO8601DateFormatter {
  convenience init(_ formatOptions: Options) {
    self.init()
    self.formatOptions = formatOptions
  }
}
