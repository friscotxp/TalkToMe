//
//  ViewControllerTranslator.swift
//  SpeakToMe
//
//  Created by Francisco Palma on 07-04-17.
//  Copyright © 2017 Henry Mason. All rights reserved.
//

import UIKit

class ViewControllerTranslator: UIViewController {
    
    @IBOutlet var text:UITextField!
    @IBOutlet var fromLanguage:UITextField!
    @IBOutlet var toLanguage:UITextField!
    @IBOutlet var translation:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func translate(_ sender: UIButton) {
        let translator = ROGoogleTranslate()
        translator.apiKey = "YOUR_API_KEY" // Add your API Key here
        
        var params = ROGoogleTranslateParams()
        params.source = fromLanguage.text ?? "de"
        params.target = toLanguage.text ?? "en"
        params.text = text.text ?? "Hallo"
        
        translator.translate(params: params) { (result) in
            DispatchQueue.main.async {
                self.translation.text = "\(result)"
            }
        }
    }
}
