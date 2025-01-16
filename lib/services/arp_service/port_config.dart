/// 整合后的常见设备端口列表
class PortConfig {
  static const List<int> commonPorts = [
    // 基础网络服务
    20,    // FTP - 数据传输
    21,    // FTP - 控制连接
    22,    // SSH - 安全远程访问
    23,    // Telnet - 远程登录
    25,    // SMTP - 邮件发送
    53,    // DNS - 域名解析
    67,    // DHCP - 服务器端
    68,    // DHCP - 客户端
    69,    // TFTP - 简单文件传输
    80,    // HTTP - Web服务
    110,   // POP3 - 邮件接收
    143,   // IMAP - 邮件访问
    161,   // SNMP - 网络管理
    162,   // SNMP Trap
    443,   // HTTPS - 安全Web服务
    
    // 文件共享和打印服务
    137,   // NetBIOS - 名称服务
    138,   // NetBIOS - 数据报
    139,   // NetBIOS - 会话服务
    445,   // SMB/CIFS - 文件共享
    515,   // LPD/LPR - 打印服务
    631,   // IPP - 互联网打印协议
    9100,  // RAW/JetDirect 打印

    // 数据库和管理服务
    1433,  // MS SQL Server
    1521,  // Oracle数据库
    3306,  // MySQL/MariaDB
    5432,  // PostgreSQL
    3389,  // RDP - 远程桌面
    10000, // Webmin管理界面

    // IoT和智能设备
    1883,  // MQTT - IoT消息协议
    5683,  // CoAP - 物联网协议
    5353,  // mDNS - 设备发现
    1900,  // SSDP - 设备发现
    49152, // UPnP - 设备发现
    
    // 流媒体和娱乐
    554,   // RTSP - 实时流协议
    1935,  // RTMP - 实时消息协议
    3074,  // Xbox Live游戏服务
    3478,  // STUN/TURN - VoIP服务
    3479,  // STUN/TURN - VoIP备用
    32469, // Plex媒体服务器
    8554,  // Live555 RTSP服务
    
    // NAS和媒体服务器
    548,   // AFP - Apple文件共享
    8096,  // Jellyfin媒体服务器
    8123,  // Home Assistant智能家居
    5001,  // Synology NAS服务
    
    // 移动设备服务
    5000,  // Android开发服务
    5555,  // Android ADB调试
    62078, // iOS服务

    // 替代端口
    8080,  // 替代HTTP端口
    8443,  // 替代HTTPS端口
    
    // 额外的服务发现端口
    5357,  // WSDAPI - Web服务发现
    3689,  // DAAP - iTunes音乐共享
  ];
}
