//
//  SerializersTests.swift
//  alamofire+groot
//
//  Created by Manuel García-Estañ on 7/10/16.
//  Copyright © 2016 ManueGE. All rights reserved.
//

import XCTest
@testable import AlamofireGroot
import CoreData
import Alamofire

class SerializersTests: XCTestCase {
    
    let apiURL = "https://api.com/path"
    var persistentContainer: NSPersistentContainer!
    
    override func setUp() {
        super.setUp()
        persistentContainer = NSPersistentContainer(inMemoryWithName: "model")
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            guard error == nil else {
                fatalError("Can't create persistent store")
            }
        }
    }
    
    override func tearDown() {
        persistentContainer = nil
        super.tearDown()
    }
    
    // MARK: Without serializer
    func testSerializeSingleManagedObject() {
        
        // given
        let responseArrived = self.expectation(description: "response of async request has arrived")
        var receivedObject: User?
        let expectedJSON: [String: Any] = ["id": 10, "name": "manueGE"]
        
        // when
        stubSuccess(with: expectedJSON)
        Alamofire.request(apiURL)
        .responseInsert(context: persistentContainer.viewContext, type: User.self) { response in
            switch response.result {
            case let .success(user):
                receivedObject = user
            case .failure:
                XCTFail("The operation shouldn't fail")
            }
            responseArrived.fulfill()
        }
        
        // then
        self.waitForExpectations(timeout: 2) { err in
            XCTAssertNotNil(receivedObject, "Received data should not be nil")
            XCTAssertEqual(receivedObject?.id, 10, "property does not match")
            XCTAssertEqual(receivedObject?.name, "manueGE", "property does not match")
            XCTAssertEqual(receivedObject?.managedObjectContext, self.persistentContainer.viewContext, "property does not match")
        }
    }
    
    // MARK: Serializer with transformer
    func testSerializingSingleManagedObjectWithTransformers() {
        
        // given 
        let responseArrived = self.expectation(description: "response of async request arrived")
        var receivedObject: User?
        let expectedJSON: [String: Any] = [
            "status": 1,
            "data": [
                "id": 10,
                "name": "manueGE"
            ]
        ]
        
        // when
        stubSuccess(with: expectedJSON)
        Alamofire.request(apiURL)
            .responseInsert(jsonSerializer: jsonTransformer, context: persistentContainer.viewContext, type: User.self) { response in
                switch response.result {
                case let .success(user):
                    receivedObject = user
                case .failure:
                    XCTFail("The operation shouldn't fail")
                }
                responseArrived.fulfill()
        }
        
        // then
        self.waitForExpectations(timeout: 2) { err in
            XCTAssertNotNil(receivedObject, "Received data should not be nil")
            XCTAssertEqual(receivedObject?.id, 10, "property does not match")
            XCTAssertEqual(receivedObject?.name, "manueGE", "property does not match")
            XCTAssertEqual(receivedObject?.managedObjectContext, self.persistentContainer.viewContext, "property does not match")
        }
    }
    
    func testFailSerializingSingleManagedObjectWithTransformers() {
        
        // given
        let responseArrived = self.expectation(description: "response of async request arrived")
        var error: Error?
        let expectedJSON: [String: Any] = [
            "status": 0,
            "error": "error message"
        ]
        
        // when
        stubSuccess(with: expectedJSON)
        Alamofire.request(apiURL)
            .responseInsert(jsonSerializer: jsonTransformer, context: persistentContainer.viewContext, type: User.self) { response in
                switch response.result {
                case .success:
                    XCTFail("The operation shouldn fail")
                case let .failure(e):
                    error = e
                }
                responseArrived.fulfill()
        }
        
        // then
        self.waitForExpectations(timeout: 2) { err in
            XCTAssertNotNil(error, "error should not be nil")
        }
    }
}

// MARK: Helpers
struct ApiError: Error {
    let message: String?
}

let jsonTransformer = DataRequest.jsonTransformerSerializer { result -> Result<Any> in
    guard result.isSuccess else {
        return result
    }
    
    let json = result.value as! [String: Any]
    let success = json["status"] as! NSNumber
    switch success.boolValue {
    case true:
        return Result.success(json["data"]!)
    default:
        return Result.failure(ApiError(message: json["error"] as? String))
    }
}