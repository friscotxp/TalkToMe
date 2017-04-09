/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The primary view controller. The speach-to-text engine is managed an configured here.
*/

import UIKit
import Speech
import AVFoundation
import Intents

public class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate{
    // MARK: Properties
    
    //private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-CL"))!
    private let speechSynthesizer = AVSpeechSynthesizer();
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @IBOutlet var textView : UITextView!
    @IBOutlet var textTranslate: UITextView!
    @IBOutlet var recordButton : UIButton!
    @IBOutlet var speakButton: UIButton!
    
    @IBOutlet var OriginPicker: UIPickerView!
    @IBOutlet var DestinyPicker: UIPickerView!
    
    var languages = ["Arabic Maged", "Czech Zuzana", "Danish Sara", "Dutch Anna", "Greek Melina", "English Karen", "English Daniel", "English Moira", "English Samantha", "English Tessa", "Spanish Monica", "Spanish Paulina", "Finnish Satu", "French Amelie", "French Thomas", "Hebrew Carmit","Hindi Lekha", "Hungarian Mariska", "Indonesian Damayanti", "Italian Alice", "Japanese Kyoko","Korean Yuna", "Dutch Ellen", "Dutch Xander", "Norwegian Nora", "Polish Zosia", "Portuguese Luciana", "Portuguese Joana","Romanian Ioana", "Russian Milena","Slovak Laura","Swedish Alva", "Thai Kanya", "Turkish Yelda", "Chinese Ting-Ting", "Chinese Sin-Ji","Chinese Mei-Jia"]
    
    var langCode = ["ar-SA","cs-CZ","da-DK","de-DE","el-GR","en-AU","en-GB","en-IE","en-US","en-ZA","es-ES","es-MX","fi-FI","fr-CA","fr-FR","he-IL","hi-IN","hu-HU","id-ID","it-IT","ja-JP","ko-KR","nl-BE","nl-NL","no-NO","pl-PL","pt-BR","pt-PT","ro-RO","ru-RU","sk-SK","sv-SE","th-TH","tr-TR","zh-CN","zh-HK","zh-TW"]
    
    var recording = false;
    var timer = Timer();
    var isRunning = false;
    var counter = 0;
    
    var languageOrigen = "";
    var languageDestino = "";
    var fromLanguage = "es";
    var toLanguage = "en";
    var translation = "";
    var speakIndex: String.CharacterView.Index?;
    
    var speakText = false;
    var speakBuffer = "";
    
    // MARK: UIViewController
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        
        if (languageOrigen == ""){
            let langCode = (Locale.current as NSLocale).object(forKey: .languageCode) as? String
            let countryCode = (Locale.current as NSLocale).object(forKey: .countryCode) as? String
            languageOrigen = "\(langCode!)-\(countryCode!)" // en-US on my machine
        }
        
        var idx = langCode.index(of: languageOrigen);
        if (idx != nil &&  idx!>0){
            OriginPicker.selectRow(langCode.index(of: "en-US")!, inComponent: 0, animated: true)
        }else{
            languages.append("Other ["+languageOrigen+"]");
            langCode.append(languageOrigen);
            idx = langCode.index(of: languageOrigen);
            OriginPicker.selectRow(langCode.index(of: languageOrigen)!, inComponent: 0, animated: true)
        }
        DestinyPicker.selectRow(langCode.index(of: "en-US")!, inComponent: 0, animated: true)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
                The callback may not be called on the main thread. Add an
                operation to the main queue to update the record button's state.
            */
            OperationQueue.main.addOperation {
                switch authStatus {
                    case .authorized:
                        self.recordButton.isEnabled = true

                    case .denied:
                        self.recordButton.isEnabled = false
                        self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)

                    case .restricted:
                        self.recordButton.isEnabled = false
                        self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)

                    case .notDetermined:
                        self.recordButton.isEnabled = false
                        self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
    }
    
    // DataSource
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return languages.count
    }
    
    // Delegate
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return languages[row]
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        /*speechSynthesizer.stopSpeaking(at: .immediate);
        language = langCode[row];
        if (fraseText.text == ""){
            speakString(phrase:  langVoices[0]);
        }else{
            speakString(phrase: fraseText.text!);
        }*/

        languageOrigen  = langCode[OriginPicker.selectedRow(inComponent: component)];
        languageDestino = langCode[DestinyPicker.selectedRow(inComponent: component)];
        print("languageOrigen : \(languageOrigen)");
        print("languageDestino : \(languageDestino)");
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageOrigen))!
        
        fromLanguage = languageOrigen.components(separatedBy: "-")[0];
        toLanguage = languageDestino.components(separatedBy: "-")[0];
        print("fromLanguage : \(fromLanguage)");
        print("toLanguage : \(toLanguage)");

    }
    
    private func startRecording() throws {
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        //try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        //textView.text = "(Go ahead, I'm listening) \(SFSpeechRecognizer.supportedLocales())";
        textView.text = "(Te escucho, habla por favor!)";
        
        //SFSpeechRecognizer.supportedLocales();
        
    }

    // MARK: SFSpeechRecognizerDelegate
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition not available", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            stopListener();
        } else {
            startListener();
        }
    }
    
    func startListener() {
        try! startRecording()
        counter = 0;
        self.speakIndex = self.textView.text.startIndex;
        runTimer();
        //CAMBIO EL BOTON PARA DETENER
        recordButton.setTitle("Stop recording", for: [])
        recordButton.setImage(UIImage(named:"record_red.png"), for: .normal);
    }

    func stopListener() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        stopTimer();
        //CAMBIO EL BOTON PARA INICIAR
        recordButton.isEnabled = false
        recordButton.setTitle("Stopping", for: .disabled)
        recordButton.setImage(UIImage(named:"record.png"), for: .normal);
    }

    
    @IBAction func speakText(_ sender: Any) {
        if !speakText{
            speakText = true;
            speakButton.setImage(UIImage(named:"Speak_green.jpg"), for: .normal);
            speakString(phrase: "Audio enabled");
        }else{
            speakString(phrase: "Audio disabled");
            speakText = false;
            speakButton.setImage(UIImage(named:"Speak.jpg"), for: .normal);
        }
    }
    
    //TIMER TO CONTROL VOICE INPUT 0,5 SEC
    func runTimer() {
        print("runTimer: INICIANDO");
        isRunning = true;
        self.timer = Timer.scheduledTimer(timeInterval: 0.5, target: self,
                                          selector: (#selector(ViewController.updateTimer)),
                                          userInfo: nil, repeats: true);
    }
    
    func stopTimer() {
        print("runTimer: FINALIZADO");
        isRunning = false;
        timer.invalidate();
    }
    
    func updateTimer() {
        if (speakBuffer != self.textView.text){
            speakBuffer = self.textView.text;
        }else{
            if (self.textView.text.substring(from: self.speakIndex!).characters.count==0){
                counter += 1;
                if counter > 30 {
                    stopListener();
                }
            }else{
                counter = 0;
                self.translate();
            }
        }
        print("TICK!! \(counter)");
    }
    
    
    //TRANSLATE THE STRING!!
    func translate() {
        if self.speakIndex==nil{
            self.speakIndex = self.textView.text.startIndex;
        }
        
        if (translation != self.textView.text.substring(from: self.speakIndex!)){
            print("Traduciendo... Origen: " + self.textView.text);
            let translator = ROGoogleTranslate()
            translator.apiKey = "AIzaSyCVwdQDg1Ps7iO5ZEM-B2zliB9VUCwXW1k"
            var params = ROGoogleTranslateParams()
            params.source = fromLanguage
            params.target = toLanguage
            
            params.text = self.textView.text.substring(from: self.speakIndex!)
            translation = self.textView.text.substring(from: self.speakIndex!)
            
            if self.textView.text.substring(from: self.speakIndex!).characters.count>0 {
                translator.translate(params: params) { (result) in
                    DispatchQueue.main.async {
                        self.textTranslate.text = "\(result)"
                        self.speakString(phrase: self.textTranslate.text);
                        print("Traduciendo... Resultado: " + self.textTranslate.text);
                        if !(self.textView.text == "(Te escucho, habla por favor!)"){
                            self.speakIndex = self.textView.text.endIndex;
                            print("self.speakIndex \(String(describing: self.speakIndex))");
                        }
                    }
                }
            }
        }else{
            print("Ya traduje eso!!!");
        }
    }
    
    //SPEAK THE STRING!!
    var rate = Float(0.5);
    var pitch = Float(1);
    var volume = Float(0.75);
    func speakString(phrase : String){
        if (speakText){
            print("Hablando: " + phrase);
            let speechUtterance = AVSpeechUtterance(string: String(describing: INSpeakableString.init(spokenPhrase: phrase)));
            speechUtterance.voice = AVSpeechSynthesisVoice(language: languageDestino);
            speechUtterance.rate = Float(rate);
            speechUtterance.pitchMultiplier = Float(pitch);
            speechUtterance.volume = Float(volume);
            speechSynthesizer.delegate = self
            speechSynthesizer.speak(speechUtterance);
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    }
    
}

