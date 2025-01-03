import UIKit
import Flutter
import SystemConfiguration.CaptiveNetwork
import CoreLocation
import Network
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.wifitool.wifisignal/wifi",
            binaryMessenger: controller.binaryMessenger
        )
        
        // 处理方法调用
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            
            switch call.method {
            case "getWifiSignalStrength":
                self.setupLocationManager()
                self.getWifiInfo { signalStrength in
                    result(signalStrength)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupLocationManager() {
        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            locationManager?.requestWhenInUseAuthorization()
        }
    }
    
    private func getWifiInfo(completion: @escaping (Int) -> Void) {
        // 检查位置权限
        let locationStatus = CLLocationManager.authorizationStatus()
        print("DEBUG: 位置权限状态: \(locationStatus.rawValue)")
        
        // 尝试获取WiFi信息
        NEHotspotNetwork.fetchCurrent { network in
            print("DEBUG: 尝试获取WiFi网络信息")
            if let network = network {
                print("DEBUG: 成功获取到WiFi网络: \(network.ssid)")
                // iOS不提供具体的信号强度，我们根据signalStrength（0-1的值）转换为dBm
                let signalStrength = Int(-100 + (network.signalStrength * 60))
                DispatchQueue.main.async {
                    completion(signalStrength)
                }
            } else {
                print("DEBUG: 未能获取到WiFi网络信息")
                DispatchQueue.main.async {
                    completion(0)
                }
            }
        }
    }
    
    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager?.startUpdatingLocation()
        default:
            break
        }
    }
}
