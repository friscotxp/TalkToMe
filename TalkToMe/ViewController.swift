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

var audioPlayer: AVAudioPlayer?
var audioRecorder: AVAudioRecorder?

public class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate, AVAudioRecorderDelegate{

    // PROPERTIES CONSTANT
    let audioSession = AVAudioSession.sharedInstance()

    // PROPERTIES VARIABLES
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-CL"))!
    private let speechSynthesizer = AVSpeechSynthesizer();
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var recording = false;
    private var timer = Timer();
    private var isRunning = false;
    private var counter = 0;
    
    private var languageOrigen = "";
    private var languageDestino = "";
    private var fromLanguage = "es";
    private var toLanguage = "en";
    private var translation = "";
    private var speakIndex: String.CharacterView.Index?;
    private var speakText = false;
    private var speakBuffer = "";
    
    private var rate = Float(0);
    private var pitch = Float(0);
    private var volume = Float(0);
    private var sendMessage = false;
    
    private var enLabels = ["Input Language", "Output Language"]
    private var esLabels = ["Idioma Origen", "Idioma Destino"]
    
    private var langLabels = ["","",""];
    
    private var enVoices = ["Input Language", "Output Language"]
    private var esVoices = ["Idioma Origen", "Idioma Destino"]
    
    private var langVoices = ["","",""];
    
    private var languagesOrigen = ["Arabic", "Czech", "Danish", "Dutch", "Greek", "English", "Spanish", "Finnish", "French", "Hebrew", "Hungarian", "Indonesian", "Italian", "Japanese","Korean", "Norwegian", "Polish", "Portuguese", "Romanian", "Russian","Slovak","Swedish", "Thai", "Turkish", "Chinese"]

    private var langCodeOrigen = ["ar-SA","cs-CZ","da-DK","de-DE","el-GR","en-US","es-ES","fi-FI","fr-FR","he-IL","hu-HU","id-ID","it-IT","ja-JP","ko-KR","no-NO","pl-PL","pt-PT","ro-RO","ru-RU","sk-SK","sv-SE","th-TH","tr-TR","zh-CN"]
    
    private var languagesDestino = ["Arabic Maged", "Czech Zuzana", "Danish Sara", "Dutch Anna", "Greek Melina", "English Karen", "English Daniel", "English Moira", "English Samantha", "English Tessa", "Spanish Monica", "Spanish Paulina", "Finnish Satu", "French Amelie", "French Thomas", "Hebrew Carmit","Hindi Lekha", "Hungarian Mariska", "Indonesian Damayanti", "Italian Alice", "Japanese Kyoko","Korean Yuna", "Dutch Ellen", "Dutch Xander", "Norwegian Nora", "Polish Zosia", "Portuguese Luciana", "Portuguese Joana","Romanian Ioana", "Russian Milena","Slovak Laura","Swedish Alva", "Thai Kanya", "Turkish Yelda", "Chinese Ting-Ting", "Chinese Sin-Ji","Chinese Mei-Jia"]
    
    private var langCodeDestino = ["ar-SA","cs-CZ","da-DK","de-DE","el-GR","en-AU","en-GB","en-IE","en-US","en-ZA","es-ES","es-MX","fi-FI","fr-CA","fr-FR","he-IL","hi-IN","hu-HU","id-ID","it-IT","ja-JP","ko-KR","nl-BE","nl-NL","no-NO","pl-PL","pt-BR","pt-PT","ro-RO","ru-RU","sk-SK","sv-SE","th-TH","tr-TR","zh-CN","zh-HK","zh-TW"]
    
    @IBOutlet var textView : UITextView!
    @IBOutlet var textTranslate: UITextView!
    @IBOutlet var recordButton : UIButton!
    @IBOutlet var speakButton: UIButton!
    @IBOutlet var OriginPicker: UIPickerView!
    @IBOutlet var DestinyPicker: UIPickerView!
    
    @IBOutlet var OriginLanguage: UILabel!
    @IBOutlet var DestinyLanguage: UILabel!
    
    public override func viewDidLoad() {
        super.viewDidLoad();
        self.audioRecordSetupMixes();
        
        if (rate == 0.0){
            rate = Float(0.5);
        }
        
        if (pitch == 0.0){
            pitch = Float(1);
        }
        
        if (volume == 0.0){
            volume = Float(1);
        }
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        
        if (languageOrigen == ""){
            let langCode = (Locale.current as NSLocale).object(forKey: .languageCode) as? String
            let countryCode = (Locale.current as NSLocale).object(forKey: .countryCode) as? String
            languageOrigen = "\(langCode!)-\(countryCode!)" // en-US on my machine
        }
        
        var idx = langCodeOrigen.index(of: languageOrigen);
        if (idx != nil &&  idx!>0){
            OriginPicker.selectRow(langCodeOrigen.index(of: "en-US")!, inComponent: 0, animated: true)
        }else{
            languagesOrigen.append("Other ["+languageOrigen+"]");
            langCodeOrigen.append(languageOrigen);
            idx = langCodeOrigen.index(of: languageOrigen);
            OriginPicker.selectRow(langCodeOrigen.index(of: languageOrigen)!, inComponent: 0, animated: true)
        }
        
        if (((Locale.current as NSLocale).object(forKey: .languageCode) as? String)=="es"){
            langVoices = esVoices
            langLabels = esLabels
        }else{
            langVoices = enVoices
            langLabels = enLabels
        }
        
        DestinyPicker.selectRow(langCodeDestino.index(of: "en-US")!, inComponent: 0, animated: true)
        languageDestino = "en-US";
        
        OriginLanguage.text=langLabels[0];
        DestinyLanguage.text=langLabels[1];
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
        //return languages.count
        if OriginPicker == pickerView {
            return languagesOrigen.count
        }
        if DestinyPicker == pickerView {
            return languagesDestino.count
        }
        return languagesOrigen.count
    }
    
    // Delegate
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if OriginPicker == pickerView {
            return languagesOrigen[row]
        }
        if DestinyPicker == pickerView {
            return languagesDestino[row]
        }
        return languagesOrigen[row]
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int){
        languageOrigen  = langCodeOrigen[OriginPicker.selectedRow(inComponent: component)];
        languageDestino = langCodeDestino[DestinyPicker.selectedRow(inComponent: component)];
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
                let range = NSMakeRange(self.textView.text.characters.count - 1, 0)
                self.textView.scrollRangeToVisible(range)
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
        stopTimer();
        audioEngine.stop();
        recognitionRequest?.endAudio();
        
        //CAMBIO EL BOTON PARA INICIAR
        recordButton.isEnabled = false
        recordButton.setTitle("Stopping", for: .disabled)
        recordButton.setImage(UIImage(named:"record.png"), for: .normal);
    }

    
    @IBAction func speakText(_ sender: Any) {
        if !speakText{
            speakText = true;
            speakButton.setImage(UIImage(named:"Speaker_RED.png"), for: .normal);
            speakString(phrase: "Audio enabled");
        }else{
            speakString(phrase: "Audio disabled");
            speakText = false;
            speakButton.setImage(UIImage(named:"Speaker.png"), for: .normal);
        }
    }
    
    //TIMER TO CONTROL VOICE INPUT 1 SEC
    func runTimer() {
        print("runTimer: INICIANDO");
        isRunning = true;
        self.timer = Timer.scheduledTimer(timeInterval: 1, target: self,
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
                if counter > 60 {
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
                        let range = NSMakeRange(self.textTranslate.text.characters.count - 1, 0)
                        self.textTranslate.scrollRangeToVisible(range)
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
    
    @IBOutlet var sendButton: UIButton!
    @IBAction func sndAction(_ sender: Any) {
        stopListener();
        audioEngine.stop();
        self.audioRecordSetupMixes();
        sendMessage = true;
        print("speakText: \(speakText)");
        
        if speakText{
            speakString(phrase: self.textTranslate.text);
        }else{
            self.sendText();
            //speakText = true;
            //speakString(phrase: self.textTranslate.text);
            //speakText = false;
        }
        recordButton.isEnabled = true;
        print("[sndAction] : " + self.textTranslate.text)
    }
    
    func open(scheme: String) {
        print("[open]")
        if let url = URL(string: scheme) {
            if #available(iOS 10, *) {
                UIApplication.shared.open(url, options: [:],
                                          completionHandler: {
                                            (success) in
                                            print("Open \(scheme): \(success)")
                })
            } else {
                _ = UIApplication.shared.openURL(url)
            }
        }
    }
    
    func sendAudio(){
        print("[sendAudio]")
        do{
            var fileSize : UInt64 = 0;
            let fileMgr = FileManager.default;
            let dirPaths = fileMgr.urls(for: .documentDirectory, in: .userDomainMask)
            let soundFileURL = dirPaths[0].appendingPathComponent("mensaje.wav")
            let attr = try FileManager.default.attributesOfItem(atPath: soundFileURL.relativePath)
            fileSize = attr[FileAttributeKey.size] as! UInt64
            if (Int(fileSize/1024)>15){
                let url = NSURL (string: "whatsapp://send?text=Hello%2C%20World!");
                if UIApplication.shared.canOpenURL(url! as URL) {
                    var controller = UIDocumentInteractionController();
                    controller = UIDocumentInteractionController(url: soundFileURL)
                    controller.uti = "net.whatsapp.audio"
                    //controller.
                    controller.delegate = self as? UIDocumentInteractionControllerDelegate
                    controller.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true)
                }else {
                    //print("error")
                    sendMessage = false;
                    speakString(phrase: langVoices[1]);
                }
            }else{
                speechSynthesizer.stopSpeaking(at: .immediate);
                speakString(phrase: langVoices[2]);
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    func sendText(){
        print("[sendAudio]")
        let urlString = self.textTranslate.text;
        let urlStringEncoded = urlString?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            let url  = NSURL(string: "whatsapp://send?text=\(urlStringEncoded!)")
            
            if UIApplication.shared.canOpenURL(url! as URL) {
                 UIApplication.shared.open(url! as URL, options: [:], completionHandler: nil)
            }
    }
    
    func speakString(phrase : String){
        print("[speakString]")
        if (speakText){
            let speechUtterance = AVSpeechUtterance(string: String(describing: INSpeakableString.init(spokenPhrase: phrase)));
            speechUtterance.voice = AVSpeechSynthesisVoice(language: languageDestino);
            speechUtterance.rate = Float(rate);
            speechUtterance.pitchMultiplier = Float(pitch);
            speechUtterance.volume = Float(volume);
            speechSynthesizer.delegate = self
            speechSynthesizer.speak(speechUtterance);
        }
    }
    
    func audioRecordSetupMixes(){
        let fileMgr = FileManager.default
        let dirPaths = fileMgr.urls(for: .documentDirectory,in: .userDomainMask)
        let soundFileURL = dirPaths[0].appendingPathComponent("mensaje.wav")
        
        let recordSettings =
            [AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue,
             AVEncoderBitRateKey: 16,
             AVNumberOfChannelsKey: 2,
             AVSampleRateKey: 22050.0] as [String : Any]
        //44100
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord);
            try audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker);
            try audioSession.setInputGain(Float (0));
        } catch {
            print("Error: \(error)")
        }
        
        do {
            try audioRecorder = AVAudioRecorder(url: soundFileURL,
                                                settings: recordSettings as [String : AnyObject])
            audioRecorder?.delegate=self
            audioRecorder?.prepareToRecord()
        } catch {
            print("Error: \(error)")
        }
    }
    
    func recordAudio() {
        print("[recordAudio]")
        if (audioRecorder?.isRecording) == false {
            audioRecorder?.record();
        }else{
            audioRecorder?.stop();
            audioRecorder?.prepareToRecord();
        }
    }
    
    func stopAudio() {
        print("[stopAudio]")
        do{
            if audioRecorder?.isRecording == true {
                audioRecorder?.stop()
            } else {
                audioPlayer?.stop()
            }
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        self.recordAudio();
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.stopAudio();
        if (self.sendMessage){
            if speakText{
                self.sendAudio();
            }else{
                self.sendText();
            }
        }
        self.sendMessage = false;
    }
}

