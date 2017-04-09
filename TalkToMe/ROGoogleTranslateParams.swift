//
//  ROGoogleTranslateParams.swift
//  SpeakToMe
//
//  Created by Francisco Palma on 07-04-17.
//  Copyright © 2017 Henry Mason. All rights reserved.
//

import Foundation

public struct ROGoogleTranslateParams {
    
    public init() {
        
    }
    
    public init(source:String, target:String, text:String) {
        self.source = source
        self.target = target
        self.text = text
    }
    
    public var source = "de"
    public var target = "en"
    public var text = "Hallo"
}


/// Offers easier access to the Google Translate API
open class ROGoogleTranslate {
    
    /// Store here the Google Translate API Key
    public var apiKey = "YOUR_API_KEY"
    
    ///
    /// Initial constructor
    ///
    public init() {
        
    }
    
    ///
    /// Translate a phrase from one language into another
    ///
    /// - parameter params:   ROGoogleTranslate Struct contains all the needed parameters to translate with the Google Translate API
    /// - parameter callback: The translated string will be returned in the callback
    ///
    open func translate(params:ROGoogleTranslateParams, callback:@escaping (_ translatedText:String) -> ()) {
        
        guard apiKey != "" else {
            print("Warning: You should set the api key before calling the translate method.")
            return
        }
        
        if let urlEncodedText = params.text.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
            if let url = URL(string: "https://translation.googleapis.com/language/translate/v2?key=\(self.apiKey)&q=\(urlEncodedText)&source=\(params.source)&target=\(params.target)&format=text") {
                
                let httprequest = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                    guard error == nil else {
                        print("Something went wrong: \(String(describing: error?.localizedDescription))")
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        
                        guard httpResponse.statusCode == 200 else {
                            
                            if let data = data {
                                print("Response [\(httpResponse.statusCode)] - \(data)")
                            }
                            
                            return
                        }
                        
                        do {
                            // Pyramid of optional json retrieving. I know with SwiftyJSON it would be easier, but I didn't want to add an external library
                            if let data = data {
                                if let json = try JSONSerialization.jsonObject(with: data, options:JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary {
                                    if let jsonData = json["data"] as? [String : Any] {
                                        if let translations = jsonData["translations"] as? [NSDictionary] {
                                            if let translation = translations.first as? [String : Any] {
                                                if let translatedText = translation["translatedText"] as? String {
                                                    callback(translatedText)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } catch {
                            print("Serialization failed: \(error.localizedDescription)")
                        }
                    }
                })
                
                httprequest.resume()
            }
        }
    }
}
