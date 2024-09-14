//
//  ViewController.swift
//  Example-Swift
//
//  Created by liujie on 2024/9/13.
//

import UIKit
import AppTrackingTransparency
import AdSupport
import AdServices

class ViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var idfaLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Attribution Demo"
        // Refresh the status when the view loads
        refreshStatus()
    }

    // Check the permission status for tracking
    func permissionStatusStr() -> String {
        var permissionStr = ""
        if #available(iOS 14.0, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            switch status {
            case .notDetermined:
                permissionStr = "Permission not determined"
            case .restricted:
                permissionStr = "Permission is restricted"
            case .denied:
                permissionStr = "No permission, check system Settings -> Privacy -> Tracking"
            case .authorized:
                permissionStr = "Permission has been granted"
            @unknown default:
                permissionStr = "Unknown permission status"
            }
        } else {
            if ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
                permissionStr = "Permission granted (System is below iOS 14)"
            } else {
                permissionStr = "No permission, please check system settings (System is below iOS 14)"
            }
        }
        return permissionStr
    }

    // Retrieve the IDFA (Identifier for Advertisers)
    func getIdfa() -> String {
        return ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }

    // Refresh the status and update the labels
    func refreshStatus() {
        statusLabel.text = "Permission status: \(permissionStatusStr())"
        idfaLabel.text = "IDFA: \(getIdfa())"
    }

    // Show the permission dialog for ad tracking (iOS 14 or later)
    @IBAction func showDialog(_ sender: Any) {
        if #available(iOS 14.0, *) {
            // Check if tracking consent is already set
            if ATTrackingManager.trackingAuthorizationStatus != .notDetermined {
                // Show alert indicating tracking consent is already set
                alertTrackingConsentIsAlreadySet()
            } else {
                // Show custom tracking consent dialog
                alertCustomTrackingConsentDialog()
            }
        } else {
            // For iOS versions below 14
            if ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
                // Ad tracking is allowed
                alertWithTitle("Notice", message: "Ad tracking is allowed")
            } else {
                // Ask the user to enable ad tracking in settings
                alertWithTitle("Notice", message: "Please enable ad tracking in Settings > Privacy")
            }
            refreshStatus() // Refresh the status
        }
    }
    
    // Function to handle the alert when tracking consent is already set
    func alertTrackingConsentIsAlreadySet() {
        alertWithTitle("Notice", message: "The system tracking consent dialog cannot be displayed because it has already been shown. To display the system tracking consent dialog again, please uninstall and reinstall the demo.")
    }
    
    // Show custom tracking consent dialog
    func alertCustomTrackingConsentDialog() {
        let alert = UIAlertController(title: "Notice",
                                      message: "Do you consent to this app obtaining tracking permission?",
                                      preferredStyle: .alert)
        
        // Allow action
        let agreeAction = UIAlertAction(title: "Allow", style: .cancel) { action in
            // Call function to show system tracking dialog
            self.alertSystemTrackingDialog()
        }
        alert.addAction(agreeAction)
        
        // Don’t Allow action
        let disagreeAction = UIAlertAction(title: "Don’t Allow", style: .default, handler: nil)
        alert.addAction(disagreeAction)
        
        // Present the alert dialog
        self.present(alert, animated: true, completion: nil)
    }
    
    // Function to request system tracking dialog
    func alertSystemTrackingDialog() {
        if #available(iOS 14.0, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    // Update your UI or status after the user responds
                    self.refreshStatus()
                }
            }
        }
    }

    // POST request to send attribution data with retry logic
    func postRequestWithToken(_ token: String, retryCount: Int = 3, success: @escaping ([String: Any]) -> Void, failure: @escaping (Error?) -> Void) {
        guard let url = URL(string: "https://api-adservices.apple.com/api/v1/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let postData = token.data(using: .utf8)
        request.httpBody = postData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                // Retry the request if there are retry attempts left
                if retryCount > 0 {
                    print("Request failed, retrying... Remaining retries: \(retryCount - 1)")
                    self.postRequestWithToken(token, retryCount: retryCount - 1, success: success, failure: failure)
                } else {
                    DispatchQueue.main.async {
                        failure(error)
                    }
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    failure(nil)
                }
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    DispatchQueue.main.async {
                        success(jsonResponse)
                    }
                } else {
                    DispatchQueue.main.async {
                        failure(nil)
                    }
                }
            } catch let jsonError {
                // Retry if JSON parsing fails
                if retryCount > 0 {
                    print("Failed to parse JSON, retrying... Remaining retries: \(retryCount - 1)")
                    self.postRequestWithToken(token, retryCount: retryCount - 1, success: success, failure: failure)
                } else {
                    DispatchQueue.main.async {
                        failure(jsonError)
                    }
                }
            }
        }
        
        task.resume()
    }

    // Action for requesting attribution data and making a POST request
    @IBAction func requestAttribution(_ sender: Any) {
        if #available(iOS 14.3, *) {
            do {
                let token = try AAAttribution.attributionToken()
                print("Token: \(token)")
                postRequestWithToken(token, success: { response in
                    print("Request succeeded with response: \(response)")
                    self.alertWithTitle("Notice", message: response.description)
                }, failure: { error in
                    print("Request failed with error: \(String(describing: error?.localizedDescription))")
                    self.alertWithTitle("Notice", message: error?.localizedDescription ?? "Unknown error")
                })
            } catch {
                print("Error obtaining token: \(error.localizedDescription)")
            }
        } else {
            // Fallback for earlier versions
        }
    }

    // Display an alert with a title and message
    func alertWithTitle(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

