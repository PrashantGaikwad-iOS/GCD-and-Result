//
//  ViewController.swift
//  GCD and Rsult
//
//  Created by Prashant Gaikwad on 17/11/19.
//  Copyright © 2019 Prashant Gaikwad. All rights reserved.
//

import UIKit

enum NetworkError: Error {
    case url
    case server
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        load()
    }

    func makeAPICall() -> Result<String?, NetworkError> {
        let path = "https://jsonplaceholder.typicode.com/todos/1"
        guard let url = URL(string: path) else {
            return .failure(.url)
        }
        var result: Result<String?, NetworkError>!

        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: url) { (data, _, _) in
            if let data = data {
                result = .success(String(data: data, encoding: .utf8))
            } else {
                result = .failure(.server)
            }
            semaphore.signal()
            }.resume()
        _ = semaphore.wait(wallTimeout: .distantFuture)
        return result
    }

    func anotherAPICall(_ param: String?) -> Result<Int, NetworkError> {
        let path = "https://jsonplaceholder.typicode.com/todos/1"
        guard let url = URL(string: path) else {
            return .failure(.url)
        }
        var result: Result<String?, NetworkError>!

        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: url) { (data, _, _) in
            if let data = data {
                result = .success(String(data: data, encoding: .utf8))
            } else {
                result = .failure(.server)
            }
            semaphore.signal()
            }.resume()
        _ = semaphore.wait(wallTimeout: .distantFuture)
        return result
    }
    func andAnotherAPICall(_ param: Int) -> Result<User, NetworkError> {
        let path = "https://jsonplaceholder.typicode.com/todos/1"
        guard let url = URL(string: path) else {
            return .failure(.url)
        }
        var result: Result<String?, NetworkError>!

        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: url) { (data, _, _) in
            if let data = data {
                result = .success(String(data: data, encoding: .utf8))
            } else {
                result = .failure(.server)
            }
            semaphore.signal()
            }.resume()
        _ = semaphore.wait(wallTimeout: .distantFuture)
        return result
    }

    func load() {
        DispatchQueue.global(qos: .utility).async {
            let result = self.makeAPICall()
                .flatMap { self.anotherAPICall($0) }
                .flatMap { self.andAnotherAPICall($0) }

            DispatchQueue.main.async {
                switch result {
                case let .success(data):
                    print(data)
                case let .failure(error):
                    print(error)
                }
            }
        }
    }

}

