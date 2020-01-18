//
//  RandomNumberPublisher.swift
//  Publishers
//
//  Created by Mikey Ward on 1/17/20.
//  Copyright © 2020 Mikey Ward. All rights reserved.
//

import Foundation
import Combine

public protocol RandomizableNumeric: Comparable {
    static func random(in range: Range<Self>) -> Self
}

extension Int: RandomizableNumeric {}
extension Int8: RandomizableNumeric {}
extension Int16: RandomizableNumeric {}
extension Int32: RandomizableNumeric {}
extension Int64: RandomizableNumeric {}
extension UInt: RandomizableNumeric {}
extension UInt8: RandomizableNumeric {}
extension UInt16: RandomizableNumeric {}
extension UInt32: RandomizableNumeric {}
extension UInt64: RandomizableNumeric {}
extension Float: RandomizableNumeric {}
extension Float80: RandomizableNumeric {}
extension Double: RandomizableNumeric {}

extension Publishers {
    public struct RandomNumbers<NumberType: RandomizableNumeric> : Publisher {
        public typealias Output = NumberType
        public typealias Failure = Never
        
        let range: Range<Output>
        let queue: DispatchQueue
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input {
                let subscription = RandomNumbersSubscription(subscriber: subscriber, range: range, queue: queue)
                subscriber.receive(subscription: subscription)
        }
    }
}

extension Publishers {
    public static func randomNumbers<Output: RandomizableNumeric>(in range: Range<Output>,
                                                                  queue: DispatchQueue = .main) -> Publishers.RandomNumbers<Output> {
        return RandomNumbers(range: range, queue: queue)
    }
}

private final class RandomNumbersSubscription<Downstream: Subscriber, NumberType: RandomizableNumeric> : Subscription
    where Downstream.Input == NumberType {
    
    var subscriber: Downstream?
    var remainingDemand: Subscribers.Demand = .none
    let range: Range<NumberType>
    let queue: DispatchQueue
    
    init(subscriber: Downstream, range: Range<NumberType>, queue: DispatchQueue) {
        self.subscriber = subscriber
        self.range = range
        self.queue = queue
    }
    
    func request(_ demand: Subscribers.Demand) {        
        remainingDemand += demand
        if remainingDemand > .none {
            emitValue()
        }
    }
    
    func emitValue() {
        guard let subscriber = subscriber else { return }
        if remainingDemand > .none {
            queue.async {
                let value: NumberType = NumberType.random(in: self.range)
                self.remainingDemand -= 1
                self.remainingDemand += subscriber.receive(value)
                self.emitValue()
            }
        }
    }
    
    func cancel() {
        remainingDemand = .none
        subscriber = nil
    }
}
