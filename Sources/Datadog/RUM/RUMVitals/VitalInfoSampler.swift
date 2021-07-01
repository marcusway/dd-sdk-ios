/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

internal final class VitalInfoSampler {
    let cpuReader: VitalCPUReader
    private let cpuPublisher = VitalPublisher(initialValue: VitalInfo())

    var cpu: VitalInfo {
        return cpuPublisher.currentValue
    }

    let memoryReader: VitalMemoryReader
    private let memoryPublisher = VitalPublisher(initialValue: VitalInfo())

    var memory: VitalInfo {
        return memoryPublisher.currentValue
    }

    let refreshRateReader: VitalRefreshRateReader
    private let refreshRatePublisher = VitalPublisher(initialValue: VitalInfo())

    var refreshRate: VitalInfo {
        return refreshRatePublisher.currentValue
    }

    private var timer: Timer?

    init(
        cpuReader: VitalCPUReader,
        memoryReader: VitalMemoryReader,
        refreshRateReader: VitalRefreshRateReader
    ) {
        self.cpuReader = cpuReader
        self.memoryReader = memoryReader
        self.refreshRateReader = refreshRateReader
        self.refreshRateReader.register(self.refreshRatePublisher)

        takeSample()
        let timer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(takeSample),
            userInfo: nil,
            repeats: true
        )
        // NOTE: RUMM-1280 non-main run loops don't fire
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer
    }

    deinit {
        self.timer?.invalidate()
    }

    @objc
    private func takeSample() {
        if let newCPUSample = cpuReader.readVitalData() {
            cpuPublisher.mutateAsync { cpuInfo in
                cpuInfo.addSample(newCPUSample)
            }
        }
        if let newMemorySample = memoryReader.readVitalData() {
            memoryPublisher.mutateAsync { memoryInfo in
                memoryInfo.addSample(newMemorySample)
            }
        }
    }
}
