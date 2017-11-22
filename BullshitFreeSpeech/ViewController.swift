//
//  ViewController.swift
//  BullshitFreeSpeech
//
//  Created by Jan on 20/11/2017.
//  Copyright © 2017 schwarja. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController {
    
    enum State {
        case idle
        case recording
    }

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var countLabel: UILabel!
    
    private var state: State = .idle {
        didSet {
            setupUI()
        }
    }
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordedTranscripts: [SFTranscription] = []
    private var recordedBullshits: [Bullshit] = []
    private var currentTranscript: SFTranscription?
    private var lastBullshitRange: Range<Int>?
    
    private var timer: Timer?
    
    private lazy var bullshits: [Bullshit] = {
        return BullshitManager.loadBullshits()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }

    @IBAction func actionButtonTapped(_ sender: Any) {
        switch state {
        case .idle:
            startRecording()
            
        case .recording:
            stopRecording()
        }
    }
    
}

private extension ViewController {
    
    func setupUI() {
        switch state {
        case .idle:
            actionButton.setTitle("Record", for: .normal)
            
        case .recording:
            actionButton.setTitle("Stop", for: .normal)
        }
    }
    
    func requestPermission(completion: @escaping (_ granted: Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorization granted")
                completion(true)
            case .denied:
                print("Speech recognition authorization denied")
                completion(false)
            case .restricted:
                print("Not available on this device")
                completion(false)
            case .notDetermined:
                print("Not determined")
                completion(false)
            }
        }
    }
    
    func startRecording() {
        textView.text = ""
        countLabel.text = "0"
        recordedTranscripts.removeAll()
        recordedBullshits.removeAll()
        state = .recording
        requestPermission { [unowned self] (granted) in
            DispatchQueue.main.async {
                if granted {
                    do {
                        try self.recordAudio()
                    }
                    catch {
                        print("Did not start to record")
                        self.state = .idle
                    }
                }
                else {
                    self.state = .idle
                }
            }
        }
    }
    
    func recordAudio() throws {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Cannot start recognizer")
            self.state = .idle
            return
        }
        
        timer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(self.restartRecording), userInfo: nil, repeats: false)
        lastBullshitRange = nil
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        self.request = request
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, tap) in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = recognizer.recognitionTask(with: request, delegate: self)
    }
    
    @objc func restartRecording() {
        print("RESTART")
        timer?.invalidate()
        resetRecognitionSession()
        do {
            try recordAudio()
        }
        catch {
            print("Restart failed")
            stopRecording()
        }
    }
    
    func updateUIWithTranscription(_ transcription: SFTranscription) {
        for bullshit in bullshits {
            if let range = rangeOfBullshit(bullshit, inTranscription: transcription) {
                lastBullshitRange = range
                recordedBullshits.append(bullshit)
                animateLabel()
                break
            }
        }
        
        self.textView.text = recordedBullshits.map({ $0.tokens.joined(separator: " ") }).joined(separator: "\n")
    }
    
    func rangeOfBullshit(_ bullshit: Bullshit, inTranscription transcription: SFTranscription) -> Range<Int>? {
        guard transcription.segments.count - bullshit.length >= (lastBullshitRange?.upperBound ?? 0) else {
            return nil
        }
        
        guard transcription.segments.count >= bullshit.length else {
            return nil
        }
        
        let phrase = Array(transcription.segments.suffix(bullshit.length)).map({ $0.substring.lowercased() }).joined(separator: " ")
        
        for token in bullshit.tokens where !phrase.contains(token) {
            return nil
        }
        
        let lower = transcription.segments.count - bullshit.length
        return Range<Int>(uncheckedBounds: (lower, lower + bullshit.length))
    }
    
    func animateLabel() {
        countLabel.text = "\(recordedBullshits.count)"
    }
    
    func stopRecording() {
        state = .idle
        timer?.invalidate()
        resetRecognitionSession()
    }
    
    func resetRecognitionSession() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        let task = recognitionTask
        recognitionTask = nil
        task?.finish()
    }
}

extension ViewController: SFSpeechRecognitionTaskDelegate {

    func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        print("Did detect speech")
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        print("Did hypothyze transcription")
        currentTranscript = transcription
        self.updateUIWithTranscription(transcription)
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        print("Did finish recognition")
        recordedTranscripts.append(recognitionResult.bestTranscription)
        self.updateUIWithTranscription(recognitionResult.bestTranscription)
    }
    
    func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        print("Finished reading audio")
        if task == recognitionTask {
            restartRecording()
        }
    }
    
    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        print("Task was cancelled")
        if state == .recording {
            stopRecording()
        }
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        print("Did finish successfully \(successfully)")
        if !successfully, let transcript = currentTranscript {
            recordedTranscripts.append(transcript)
            currentTranscript = nil
        }
    }

}
