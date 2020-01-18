//
//  main.swift
//  Publishers
//
//  Created by Mikey Ward on 1/17/20.
//  Copyright © 2020 Mikey Ward. All rights reserved.
//

import Foundation
import Combine

var subscriptions = Set<AnyCancellable>()

print("Hello, World!")

Publishers.randomNumbers(in: 95.0..<105.0)
    .roundedTo(place: 0.01)
    .rollingGroup(of: 5)
    .periodicallyRepeat(interval: 1.0, maxFudge: 0, queue: .main)
    .sink { print("OUTPUT Latest buffer: \($0)") }
    .store(in: &subscriptions)

RunLoop.current.run()
