//
//  RollingPublisher.swift
//  Publishers
//
//  Created by Mikey Ward on 1/17/20.
//  Copyright © 2020 Mikey Ward. All rights reserved.
//

import Foundation
import Combine

extension Publishers {
    
    public struct RollingGroup<Upstream: Publisher>: Publisher {
        
        public typealias Input = Upstream.Output
        public typealias Output = [Upstream.Output]
        public typealias Failure = Upstream.Failure
        
        public let combineIdentifier = CombineIdentifier()
        
        let upstreamPublisher: Upstream
        let maxBufferSize: Int

        // MARK: Publisher
                
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input {
                    
                let subscription = RollingGroupSubscription<Upstream,Downstream>(subscriber: subscriber,
                                                                                      upstreamPublisher: upstreamPublisher,
                                                                                      maxBufferSize: maxBufferSize)
                subscriber.receive(subscription: subscription)
                upstreamPublisher.receive(subscriber: subscription)
        }
        
    }

}

extension Publisher {
    
    public func rollingGroup(of maxBufferSize: Int) -> Publishers.RollingGroup<Self> {
        let publisher = Publishers.RollingGroup<Self>(upstreamPublisher: self, maxBufferSize: maxBufferSize)
        return publisher
    }
    
}

private final class RollingGroupSubscription<Upstream: Publisher, Downstream: Subscriber>: Subscription
    where Downstream.Input == [Upstream.Output],
          Upstream.Failure == Downstream.Failure {
    
    var maxBufferSize: Int
    var buffer = [Upstream.Output]()
    
    var remainingDemand = Subscribers.Demand.none
    var subscriber: Downstream? = nil
    var upstreamPublisher: Upstream? = nil
    var upstreamSubscription: Subscription? = nil
    
    init(subscriber: Downstream, upstreamPublisher: Upstream, maxBufferSize: Int) {
        self.maxBufferSize = maxBufferSize
        self.upstreamPublisher = upstreamPublisher
        self.subscriber = subscriber
        buffer.reserveCapacity(maxBufferSize)
    }
        
    func request(_ demand: Subscribers.Demand) {
        remainingDemand += demand
        
        if remainingDemand > .none {
            upstreamSubscription?.request(demand)
        }
    }
    
    func cancel() {
        remainingDemand = .none
        subscriber = nil
    }
}
    
extension RollingGroupSubscription: Subscriber {
    
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    
    func receive(subscription: Subscription) {
        subscription.request(remainingDemand)
        self.upstreamSubscription = subscription
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        guard let subscriber = subscriber, remainingDemand > .none else { return .none }
        
        buffer.append(input)
        buffer = buffer.suffix(maxBufferSize)
        
        return subscriber.receive(buffer)
    }
    
    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        subscriber?.receive(completion: completion)
        buffer.removeAll()
        subscriber = nil
        upstreamPublisher = nil
    }
    
}
