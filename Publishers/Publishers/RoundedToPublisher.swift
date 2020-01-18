//
//  RoundedToPublisher.swift
//  Publishers
//
//  Created by Mikey Ward on 1/17/20.
//  Copyright © 2020 Mikey Ward. All rights reserved.
//

import Foundation
import Combine

extension Publisher {
    
    /// Rounds floating point inputs to the specified place.
    ///
    /// - Parameter place: Least digit to round to. Given _123.45_, a `place` of 10 would yield 120, where a `place` of _0.1_ would yield _123.4_.
    ///
    func roundedTo<NumberType: FloatingPoint>(place: NumberType) -> Publishers.Map<Self, NumberType> where Output == NumberType {
        map { ($0 * 1/place).rounded() * place }
    }
}
