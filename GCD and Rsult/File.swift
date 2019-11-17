//
//  File.swift
//  GCD and Rsult
//
//  Created by Prashant Gaikwad on 17/11/19.
//  Copyright © 2019 Prashant Gaikwad. All rights reserved.
//
/*
Swift 5: How to do Async/Await with Result and GCD

Why wait for Apple to add Async/Await to Swift when you can have it now?
Michael Long
Michael Long
Following
May 1 · 7 min read

Swift 5.0 brought several new language enhancements along with ABI stability, and one of those was adding Result to the standard library. Result gives us a simpler, clearer way of handling errors in complex code such as asynchronous APIs.
And especially when chaining multiple API calls together.
Overview
Using Result and Grand Central Dispatch (GCD), we’ll be able to write pure Swift code like the following:
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
Here our load function makes several consecutive API calls in the background, each time passing the result of one call to the next. We then handle the final result back on the main thread, or in the case of one of our calls failing, we handle the resulting error.
Ready? Then let’s dig in and see how it’s done.
Using Result
As you may be aware, Swift’s Result type is implemented as an enum that has two cases: success and failure.
Both values are defined using generics so they can have an associated value of your choosing, but failure must be something that conforms to Swift’s Error type.
enum NetworkError: Error {
    case url
    case server
}
func makeAPICall() -> Result<String?, NetworkError> {
    // our network code
}
So in the above sample, you can see that we have a function that returns a Result whose data type is an optional String, and whose error type is of type NetworkError.
So let’s look at the calling code and see how we might call our function and handle our result:
func load() {
    DispatchQueue.global(qos: .utility).async {
        let result = self.makeAPICall()
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
Our load function puts our call on a concurrent background thread using DispatchQueue.global(qos: .utility).async, and then calls our makeAPICall.
It then switches back to the main thread to handle the result, which is either the data we wanted (success) or an error of type NetworkError (failure).
Nice and clean.
That said, you might be a little confused at this point, because usually when we make an API call we normally need to use some sort of callback closure to handle our result, but here we’re simply assigning the result of our function to our local result.
Well, this is where Grand Central Dispatch (GCD) comes into play.
Making API Calls Using Result
First, let’s actually implement our makeAPICall function. Here we’ll flesh out our function, define our url, and create a placeholder for the return result.
func makeAPICall() -> Result<String?, NetworkError> {
    let path = "https://jsonplaceholder.typicode.com/todos/1"
    guard let url = URL(string: path) else {
        return .failure(.url)
    }
    var result: Result<String?, NetworkError>!
    // API Call Goes Here
    return result
}
Note in the guard statement how we return a Result.failure(.url) if for some reason we have a bad URL.
Now let’s construct a standard API call using URLSession.
URLSession.shared.dataTask(with: url) { (data, _, _) in
    if let data = data {
        result = .success(String(data: data, encoding: .utf8))
    } else {
        result = .failure(.server)
    }
    }.resume()
This is fairly straightforward. If our callback function has data, we assign it to our result as a .success value.
And if we have an error, we assign our .server enum value to .failure. We could inspect the response and error values if we want to do a better job of notifying our caller of exactly what went wrong, but this is good enough for now.
We’ve successfully translated our callback results into a Result, but our code is still incomplete in that our function will attempt to return our result value before our dataTask callback occurs.
In fact, our code will crash since result was defined as an implicitly unwrapped optional and our function will attempt to unwrap it before it’s assigned!
That’s not good, so let’s fix that.
Making API Calls Using CGD Semaphores
We already have most of what we need, so let’s add the three lines of code that make our function work.
For clarity, I’ll show the entire makeAPICall function code.
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
After we define our Result, we create a Grand Central Dispatch semaphore with a value of 0.
As you may recall, semaphores are often used in multithreaded applications to block access to a given code block until the block completes. You block access by waiting on the semaphore, and you grant access by calling signal on the semaphore.
In the above code, calling semaphore.wait after we start our dataTask API call blocks access to the next line of code, our return statement. This halts the current thread at that point.
When the callback function executes on its thread we assign the data or error to our function’s internal result value and then call semaphore.signal().
That, in turn, allows our original function’s thread to continue and return the result we’ve just assigned, which is then assigned to the result value in our load function.
And now we have the answer as to how we can magically assign the result of an asynchronous call in a seemingly synchronous manner.
Chaining Multiple API Calls
You’ll recall that our original example demonstrated “chaining” API calls, which is one of the tricks you traditionally get using async/await.
func processImageData1() async -> Image {
    let dataResource  = await loadWebResource("dataprofile.txt")
    let imageResource = await loadWebResource("imagedata.dat")
    let imageTmp      = await decodeImage(dataResource, imageResource)
    let imageResult   = await dewarpAndCleanupImage(imageTmp)
    return imageResult
}
For our example, let’s assume that we have a couple more API calls that look like the following:
func anotherAPICall(_ param: String?) -> Result<Int, NetworkError>
{ ... }
func andAnotherAPICall(_ param: Int) -> Result<User, NetworkError>
{ ... }
And that those functions are implemented using GCD and Result exactly as we’ve done with our intial makeAPICall().
Given that, and assuming we want to execute those calls consecutively first one, then the other, our load function now looks exactly as shown in our very first example:
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
FlatMap?
There are several operations defined on Result, and one of them is called flatMap.
Using FlatMap on a Result passes the value of the current Result to a map closure that in turn can return a new Result of the same or of a different type. (IOW, we map a Result<A, MyError> to a Result<B, MyError>)
In the above code, we use flatMap to take the optional string Result of our first call and pass it to our first closure, which makes our second API call which returns its own Result.
We then pass the integer value from that result to our second closure which contains our third API call, which finally returns a Result containing our loaded User.
Each one waits on the result of the previous API call before proceding.
Voila! Chained API calls using Result, GCD, and flatMap.
Ummm… What About Errors?
You might wonder what happens if the first API call fails with an error?
Well, in that case flatMap doesn’t call the closure containing anotherAPICall() and simply passes on the .failure case returned by makeAPICall().
That happens again with the next flatMap and andAnotherAPICall(), and Swift finally ends up assigning the first failure result to our final result variable, which is then handled by the switch statement.
The same thing occurs if the second or third API call fails, in that anything past the error state will not be called.
Threading
One final point worth mentioning is that semaphore.wait() will block the current thread until it’s unblocked by semaphore.signal().
That’s why in our load function we started the whole process by throwing our requests onto a background utility thread that we can pause and resume at will, and then when we’re done we switch to our main thread in order to update our UI with the results.
Blocking the main thread with semaphore.wait() will block your user interface until your API calls complete, so ALWAYS use this technique on a background thread or operation block.
So there you have it. Apple adding Result to the Swift Standard Library gives not only gives us a better way to unambiguously handle API results, but also gives us a better way to manage chaining multiple API calls together and avoid the pyramid of doom.
If you have any questions just leave ’em in the comments below.
And as always. Enjoy.

 */
