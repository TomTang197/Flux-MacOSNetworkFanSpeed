//
//  FanViewModel.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//  Modified for Read-Only monitoring on 14/02/26.
//

import Foundation
import Combine

class FanViewModel: ObservableObject {
    @Published var fans: [FanInfo] = []
    @Published var primaryTemp: String = "--°C"
    
    private var timer: Timer?
    private let smc = SMCService.shared
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateData()
        }
        updateData()
    }
    
    private func updateData() {
        // Update Fans
        var updatedFans: [FanInfo] = []
        // Standard check for up to 2 fans (typical for Mac laptops)
        for i in 0..<2 {
            if let rpm = smc.getFanRPM(i) {
                // For monitoring, we use default min/max if not easily available
                // Modern Silicon Macs vary wildly, so we focus on current RPM
                updatedFans.append(FanInfo(
                    id: i,
                    name: "Fan \(i + 1)",
                    currentRPM: rpm,
                    minRPM: 1200, 
                    maxRPM: 6000,
                    isManual: false
                ))
            }
        }
        
        // Update Temperatures (Common CPU PECI or Silicon P-Core keys)
        let tempKeys = ["TC0P", "Tp0P", "Tp01"] 
        var foundTemp: Double?
        for key in tempKeys {
            if let t = smc.getTemperature(key) {
                foundTemp = t
                break
            }
        }
        
        DispatchQueue.main.async {
            self.fans = updatedFans
            if let t = foundTemp {
                self.primaryTemp = String(format: "%.1f°C", t)
            } else {
                self.primaryTemp = "--°C"
            }
        }
    }
}
