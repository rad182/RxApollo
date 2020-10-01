//
//  RxApollo.swift
//  RxApollo
//
//  Created by Scott Hoyt on 5/9/17.
//  Copyright © 2017 Scott Hoyt. All rights reserved.
//

import Foundation
import RxSwift
import Apollo
import AlamofireNetworkActivityIndicator

/// An `Error` emitted by `ApolloReactiveExtensions`.
public enum RxApolloError: Error {
    /// One or more `GraphQLError`s were encountered.
    case graphQLErrors([GraphQLError])
    case unknown
}

/// Reactive extensions for `ApolloClient`.
extension Reactive where Base: ApolloClient {

    /// Fetches a query from the server or from the local cache, depending on the current contents of the cache and the specified cache policy.
    ///
    /// - Parameters:
    ///   - query: The query to fetch.
    ///   - cachePolicy: A cache policy that specifies when results should be fetched from the server and when data should be loaded from the local cache.
    ///   - queue: A dispatch queue on which the result handler will be called. Defaults to the main queue.
    /// - Returns: A `Observable` that emits the results of the query.
    @discardableResult public func fetch<Query: GraphQLQuery>(
        query: Query,
        cachePolicy: CachePolicy = .returnCacheDataElseFetch,
        queue: DispatchQueue = DispatchQueue.main) -> Observable<Query.Data> {
        NetworkActivityIndicatorManager.shared.incrementActivityCount()

        return Observable.create { [weak base] (subscriber) -> Disposable in
            let cancellable = base?.fetch(query: query, cachePolicy: cachePolicy, context: nil, queue: queue) { result in
                NetworkActivityIndicatorManager.shared.decrementActivityCount()
                switch result {
                case .success(let result):
                    if let errors = result.errors {
                        subscriber.onError((RxApolloError.graphQLErrors(errors)))
                    } else if let data = result.data {
                        subscriber.onNext(data)

                        if cachePolicy == .returnCacheDataAndFetch {
                            if result.source == .server {
                                subscriber.onCompleted()
                            }
                        } else {
                            subscriber.onCompleted()
                        }
                    } else {
                        subscriber.onError(RxApolloError.unknown)
                    }
                case .failure(let error):
                  // Network or response format errors
                  subscriber.onError(error)
                }
            }

            return Disposables.create {
                cancellable?.cancel()
            }
        }
    }

    /// Performs a mutation by sending it to the server.
    ///
    /// - Parameters:
    ///   - mutation: The mutation to perform.
    ///   - queue: A dispatch queue on which the result handler will be called. Defaults to the main queue.
    /// - Returns: A `Single` that emits the results of the mutation.
    public func perform<Mutation: GraphQLMutation>(mutation: Mutation, queue: DispatchQueue = DispatchQueue.main) -> Single<Mutation.Data> {
        NetworkActivityIndicatorManager.shared.incrementActivityCount()
        return Single.create { [weak base] single in
            let cancellable = base?.perform(mutation: mutation, context: nil, queue: queue) { (result) in
                NetworkActivityIndicatorManager.shared.decrementActivityCount()
                switch result {
                case .success(let result):
                    if let errors = result.errors {
                        single(.error(RxApolloError.graphQLErrors(errors)))
                    } else if let data = result.data {
                        single(.success(data))
                    } else {
                        single(.error(RxApolloError.unknown))
                    }
                case .failure(let error):
                  // Network or response format errors
                  single(.error(error))
                }
            }

            return Disposables.create {
                cancellable?.cancel()
            }
        }
    }
}

extension ApolloClient: ReactiveCompatible {}
