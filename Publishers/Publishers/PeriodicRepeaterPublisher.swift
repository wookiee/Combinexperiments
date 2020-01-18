//
//  CadencePublisher.swift
//  Publishers
//
//  Created by Mikey Ward on 1/17/20.
//  Copyright © 2020 Mikey Ward. All rights reserved.
//

import Foundation
import Combine

struct PeriodicRepeaterConfiguration {
    /// Grand Central Dispatch queue upon which to publish events.
    let queue: DispatchQueue
    /// Expected period between publications.
    let interval: TimeInterval
    /// A value from `0.0 ... 1.0`.
    /// The interval will be adjusted by ± a random percentage up to `maxFudge` for each publication,
    /// creating inconsistently-timed output.
    /// Useful for simulating real-world data.
    /// Values larger than the interval itself will be rounded down to the interval.
    let maxFudge: Double
    
    init(interval: TimeInterval, maxFudge: Double = 0.0, queue: DispatchQueue = .main) {
        self.queue = queue
        self.interval = interval
        self.maxFudge = maxFudge
    }
}

extension Publisher {
    /// Receives values from upstream publisher and periodically emits its latest value
    /// on a specified cadence, with a specified randomizing factor.
    ///
    /// - Parameters:
    ///     - interval: the expected time interval between emissions
    ///     - maxFudge: a multiplier between 0 and 1 that will be used to generate random offsets for each emission timer
    ///     - queue: a GCD queue upon which to publish its value
    ///
    public func periodicallyRepeat(interval: TimeInterval, maxFudge: Double = 0.0, queue: DispatchQueue = .main) -> Publishers.PeriodicRepeater<Self> {
        let configuration = PeriodicRepeaterConfiguration(interval: interval, maxFudge: maxFudge, queue: queue)
        let publisher = Publishers.PeriodicRepeater<Self>(upstreamPublisher: self, configuration: configuration)
        return publisher
    }
}

extension Publishers {
    public struct PeriodicRepeater<Upstream: Publisher> : Publisher {
        public typealias Input = Upstream.Output
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        public let combineIdentifier = CombineIdentifier()
        
        private let upstreamPublisher: Upstream
        private let configuration: PeriodicRepeaterConfiguration
        
        init(upstreamPublisher: Upstream, configuration: PeriodicRepeaterConfiguration) {
            self.upstreamPublisher = upstreamPublisher
            self.configuration = configuration
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input {
                    
                let subscription = PeriodicRepeaterSubscription<Upstream,Downstream>(subscriber: subscriber,
                                                                                     upstreamPublisher: upstreamPublisher,
                                                                                     configuration: configuration)
                subscriber.receive(subscription: subscription)
                upstreamPublisher.receive(subscriber: subscription)
        }
    }
}

private final class PeriodicRepeaterSubscription<Upstream: Publisher, Downstream: Subscriber> : Subscription
    where Downstream.Input == Upstream.Output,
          Upstream.Failure == Downstream.Failure {
    
    var remainingDemand = Subscribers.Demand.none
    var subscriber: Downstream? = nil
    var upstreamPublisher: Upstream? = nil
    var upstreamSubscription: Subscription? = nil
    var currentValue: Upstream.Output?

    let config: PeriodicRepeaterConfiguration
    
    init(subscriber: Downstream, upstreamPublisher: Upstream, configuration: PeriodicRepeaterConfiguration) {
        self.upstreamPublisher = upstreamPublisher
        self.subscriber = subscriber
        self.config = configuration
    }
    
    func cancel() {
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
        currentValue = nil
        subscriber = nil
    }
    
    func request(_ demand: Subscribers.Demand) {
        remainingDemand += demand
        
        if remainingDemand > .none {
            scheduleEmission()
        }
        
    }
    
    private func scheduleEmission() {
        
        let fudge = config.maxFudge == 0 ? 0 // Only compute fudge factor if maxFudge is nonzero
                : (Bool.random() ? 1 : -1) * Double.random(in: 0 ..< config.maxFudge) * config.interval
        
        config.queue.asyncAfter(deadline: .now() + config.interval + fudge) {
            self.emitCurrentValue()
            self.scheduleEmission()
        }
    }
    
    private func emitCurrentValue() {
        guard let subscriber = self.subscriber,
            let currentValue = self.currentValue,
            remainingDemand > .none else { return }
        
        self.upstreamSubscription?.request(.max(1))
        self.remainingDemand -= 1
        self.remainingDemand += subscriber.receive(currentValue)
    }
}

extension PeriodicRepeaterSubscription: Subscriber {
    
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    
    func receive(subscription: Subscription) {
        subscription.request(.max(1))
        self.upstreamSubscription = subscription
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        currentValue = input
        return .none
    }
    
    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        subscriber?.receive(completion: completion)
        currentValue = nil
        subscriber = nil
        upstreamPublisher = nil
    }
    
}
