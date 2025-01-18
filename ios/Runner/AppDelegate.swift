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
            name: "wifi.luuu.com/wifi",
            binaryMessenger: controller.binaryMessenger
        )
        
        // 初始化位置管理器并请求权限
        setupLocationManager()
        
        // 处理方法调用
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            
            switch call.method {
            case "getWifiSignalStrength":
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
            // 请求位置权限
            locationManager?.requestWhenInUseAuthorization()
            // 同时请求精确位置权限
            if #available(iOS 14.0, *) {
                locationManager?.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "WiFiSignal")
            }
        }
    }
    
    private func getWifiInfo(completion: @escaping (Int) -> Void) {
        // 检查位置权限
        let locationStatus = CLLocationManager.authorizationStatus()
        print("DEBUG: 位置权限状态: \(locationStatus.rawValue)")
        
        guard locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways else {
            print("DEBUG: 位置权限未授权")
            completion(0)
            return
        }
        
        // 使用CNCopyCurrentNetworkInfo API获取WiFi信息
            guard let interfaces = CNCopySupportedInterfaces() as? [String] else {
                print("DEBUG: 无法获取网络接口")
                completion(0)
                return
            }
            
            for interface in interfaces {
                if let networkInfo = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any] {
                    print("DEBUG: 成功获取到WiFi网络: \(networkInfo["SSID"] ?? "Unknown")")
                    // 由于旧API不提供信号强度，返回一个默认值
                    DispatchQueue.main.async {
                        completion(-65) // 返回一个中等信号强度的默认值
                    }
                    return
                }
            }
            
            print("DEBUG: 未能获取到WiFi网络信息")
            DispatchQueue.main.async {
                completion(0)
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
    
    private func checkSystemNetworkingPermissions() -> String? {
        // 检查WiFi信息访问权限
        let wifiInfoAccess = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.networking.wifi-info") as? Bool
        if wifiInfoAccess != true {
            return "WiFi信息访问权限未配置"
        }
        return nil
    }
}
