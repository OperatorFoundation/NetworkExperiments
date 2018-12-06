import XCTest
@testable import NetworkExperiments

import Network

final class NetworkExperimentsTests: XCTestCase
{
    func testTCPConnect()
    {
        let connected = expectation(description: "Connection callback called")
        
        guard let listener = try? NWListener(using: .tcp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
        }
        listener.start(queue: .global())
        
        let conn = NWConnection(host: NWEndpoint.Host("localhost"), port: NWEndpoint.Port(integerLiteral: 5555), using: .tcp)
        conn.start(queue: .global())
        
        wait(for: [connected], timeout: 10)
    }
    
    func testTCPSend()
    {
        let connected = expectation(description: "Connection callback called")
        let sent = expectation(description: "TCP data sent")
        
        let sendQueue = DispatchQueue(label: "sending")
        let receiveQueue = DispatchQueue(label: "receiving")
        
        // TCP allows you to send data larger than the maximum packet size
        let data = Data(repeating: 0x40, count: 20)
        
        guard let listener = try? NWListener(using: .tcp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
        }
        listener.start(queue: receiveQueue)
        
        let conn = NWConnection(host: NWEndpoint.Host("localhost"), port: NWEndpoint.Port(integerLiteral: 5555), using: .tcp)
        conn.start(queue: sendQueue)
        
        // UDP server newConnectionHandler only called when data is sent
        conn.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({
            (maybeError) in
            
            sent.fulfill()
        }))
        
        wait(for: [connected, sent], timeout: 10)
    }
    
    func testTCPReceive()
    {
        let connected = expectation(description: "Connection callback called")
        let received = expectation(description: "UDP data received")
        
        let receiveQueue = DispatchQueue(label: "receiving")
        
        guard let listener = try? NWListener(using: .tcp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
            
            newConn.receive(minimumIncompleteLength: 1, maximumLength: 1024)
            {
                (maybeData, maybeContext, isComplete, maybeError) in
                
                guard let receivedData = maybeData else
                {
                    XCTFail("Empty data received")
                    return
                }
                
                received.fulfill()
            }
            
            // You have to call start on the new connection
            newConn.start(queue: receiveQueue)
        }
        print(listener)
        listener.start(queue: receiveQueue)
        
        wait(for: [connected, received], timeout: 10)
    }

    func testTCPLargeReceive()
    {
        let connected = expectation(description: "Connection callback called")
        let received = expectation(description: "UDP data received")
        
        let receiveQueue = DispatchQueue(label: "receiving")
        
        let dataSize=200000
        
        guard let listener = try? NWListener(using: .tcp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
            
            newConn.receive(minimumIncompleteLength: dataSize, maximumLength: dataSize)
            {
                (maybeData, maybeContext, isComplete, maybeError) in
                
                guard let receivedData = maybeData else
                {
                    XCTFail("Empty data received")
                    return
                }
                
                XCTAssertEqual(receivedData.count, dataSize)
                
                received.fulfill()
            }
            
            // You have to call start on the new connection
            newConn.start(queue: receiveQueue)
        }
        print(listener)
        listener.start(queue: receiveQueue)
        
        wait(for: [connected, received], timeout: 10)
    }
    
    func testTCPSendReceive()
    {
        let connected = expectation(description: "Connection callback called")
        let sent = expectation(description: "TCP data sent")
        let received = expectation(description: "TCP data received")

        let sendQueue = DispatchQueue(label: "sending")
        let receiveQueue = DispatchQueue(label: "receiving")

        // TCP allows you to send data larger than the maximum packet size
        let data = Data(repeating: 0x40, count: 2000)
        
        guard let listener = try? NWListener(using: .tcp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
            
            newConn.receive(minimumIncompleteLength: 1, maximumLength: 1024)
            {
                (maybeData, maybeContext, isComplete, maybeError) in
                
                received.fulfill()
            }
            
            // You have to call start on the new connection
            newConn.start(queue: receiveQueue)
        }
        listener.start(queue: receiveQueue)
        
        let conn = NWConnection(host: NWEndpoint.Host("localhost"), port: NWEndpoint.Port(integerLiteral: 5555), using: .tcp)
        conn.start(queue: sendQueue)
        
        conn.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({
            (maybeError) in
            
            sent.fulfill()
        }))
        
        wait(for: [connected, sent, received], timeout: 10)
    }

    func testTCPLargeSendReceive()
    {
        let connected = expectation(description: "Connection callback called")
        let sent = expectation(description: "TCP data sent")
        let received = expectation(description: "TCP data received")
        
        let sendQueue = DispatchQueue(label: "sending")
        let receiveQueue = DispatchQueue(label: "receiving")
        
        // TCP allows you to send data larger than the maximum packet size
        let data = Data(repeating: 0x40, count: 20000)
        let dataSize = data.count
        
        guard let listener = try? NWListener(using: .tcp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
            
            newConn.receive(minimumIncompleteLength: dataSize, maximumLength: dataSize)
            {
                (maybeData, maybeContext, isComplete, maybeError) in
                
                guard let receivedData = maybeData else
                {
                    XCTFail("Empty data received")
                    return
                }
                
                XCTAssertEqual(receivedData.count, dataSize)
                
                received.fulfill()
            }
            
            // You have to call start on the new connection
            newConn.start(queue: receiveQueue)
        }
        listener.start(queue: receiveQueue)
        
        let conn = NWConnection(host: NWEndpoint.Host("localhost"), port: NWEndpoint.Port(integerLiteral: 5555), using: .tcp)
        conn.start(queue: sendQueue)
        
        conn.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({
            (maybeError) in
            
            sent.fulfill()
        }))
        
        wait(for: [connected, sent, received], timeout: 10)
    }
    
    func testUDPConnect()
    {
        let connected = expectation(description: "Connection callback called")
        let sent = expectation(description: "UDP data sent")

        let data = "test".data(using: .utf8)
        
        guard let listener = try? NWListener(using: .udp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
        }
        listener.start(queue: .global())
        
        let conn = NWConnection(host: NWEndpoint.Host("localhost"), port: NWEndpoint.Port(integerLiteral: 5555), using: .udp)
        conn.start(queue: .global())
        
        // UDP server newConnectionHandler only called when data is sent
        conn.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({
            (maybeError) in
            
            sent.fulfill()
        }))
        
        wait(for: [connected, sent], timeout: 10)
    }
    
    func testUDPLargeSendReceive()
    {
        let connected = expectation(description: "Connection callback called")
        let sent = expectation(description: "UDP data sent")
        let received = expectation(description: "UDP data received")
        
        let sendQueue = DispatchQueue(label: "sending")
        let receiveQueue = DispatchQueue(label: "receiving")
        
        // Maximum UDP size for some reason is 9216. Larger than this and the test will throw and error
        let data = Data(repeating: 0x40, count: 9216)
        let dataSize = data.count
        
        guard let listener = try? NWListener(using: .udp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
            
            newConn.receive(minimumIncompleteLength: dataSize, maximumLength: dataSize)
            {
                (maybeData, maybeContext, isComplete, maybeError) in
                
                guard let receivedData = maybeData else
                {
                    XCTFail("Empty data received")
                    return
                }
                
                XCTAssertEqual(receivedData.count, dataSize)
                XCTAssertEqual(receivedData, data)
                
                received.fulfill()
            }
            
            // You have to call start on the new connection
            newConn.start(queue: receiveQueue)
        }
        listener.start(queue: receiveQueue)
        
        let conn = NWConnection(host: NWEndpoint.Host("localhost"), port: NWEndpoint.Port(integerLiteral: 5555), using: .udp)
        conn.start(queue: sendQueue)
        
        conn.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({
            (maybeError) in
            
            sent.fulfill()
        }))
        
        wait(for: [connected, sent, received], timeout: 10)
    }
    
    func testUDPReceive()
    {
        let connected = expectation(description: "Connection callback called")
        let received = expectation(description: "UDP data received")
        
        let receiveQueue = DispatchQueue(label: "receiving")
        
        guard let listener = try? NWListener(using: .udp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
            
            newConn.receive(minimumIncompleteLength: 1, maximumLength: 1024)
            {
                (maybeData, maybeContext, isComplete, maybeError) in
                
                guard let receivedData = maybeData else
                {
                    XCTFail("Empty data received")
                    return
                }
                print(receivedData.count)
                
                received.fulfill()
            }
            
            // You have to call start on the new connection
            newConn.start(queue: receiveQueue)
        }
        listener.start(queue: receiveQueue)
        
        wait(for: [connected, received], timeout: 10)
    }

    func testUDPLargeReceive()
    {
        let connected = expectation(description: "Connection callback called")
        let received = expectation(description: "UDP data received")
        
        let receiveQueue = DispatchQueue(label: "receiving")
        
        print(NWParameters.udp)
        
        guard let listener = try? NWListener(using: .udp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
            
            // UDP receive ignores minimumIncompleteLength and returns a full UDP packet
            // 1024 bytes when tested with a local netcat client
            newConn.receive(minimumIncompleteLength: 9216, maximumLength: 9216)
            {
                (maybeData, maybeContext, isComplete, maybeError) in
                
                guard let receivedData = maybeData else
                {
                    XCTFail("Empty data received")
                    return
                }
                print(receivedData.count)
                
                XCTAssertEqual(receivedData.count, 1024)
                
                received.fulfill()
            }
            
            // You have to call start on the new connection
            newConn.start(queue: receiveQueue)
        }
        listener.start(queue: receiveQueue)
        
        wait(for: [connected, received], timeout: 10)
    }

    func testUDPSmallReceive()
    {
        let connected = expectation(description: "Connection callback called")
        let received1 = expectation(description: "UDP data received")
        let received2 = expectation(description: "UDP data received")

        let receiveQueue = DispatchQueue(label: "receiving")

        let data = Data(repeating: 0x40, count: 1024)
        
        guard let listener = try? NWListener(using: .udp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
            
            // In this test, we send 1024 bytes using netcat.
            // We then read the bytes using two receives (1 bytes and 1023 bytes).
            newConn.receive(minimumIncompleteLength: 1, maximumLength: 1)
            {
                (maybeData, maybeContext, isComplete, maybeError) in
                
                guard let receivedData1 = maybeData else
                {
                    XCTFail("Empty data received")
                    return
                }
                print(receivedData1.count)
                
                XCTAssertEqual(receivedData1.count, 1)
                
                received1.fulfill()
                
                newConn.receive(minimumIncompleteLength: 1023, maximumLength: 1023)
                {
                    (maybeData, maybeContext, isComplete, maybeError) in
                    
                    guard let receivedData2 = maybeData else
                    {
                        XCTFail("Empty data received")
                        return
                    }
                    print(receivedData2.count)
                    
                    XCTAssertEqual(receivedData2.count, 1023)
                    
                    var receivedData = receivedData1
                    receivedData.append(receivedData2)
                    
                    XCTAssertEqual(receivedData, data)
                    
                    received2.fulfill()
                }
            }
            
            // You have to call start on the new connection
            newConn.start(queue: receiveQueue)
        }
        listener.start(queue: receiveQueue)
        
        wait(for: [connected, received1, received2], timeout: 10)
    }

    func testUDPMultipacketSmallReceive()
    {
        let connected = expectation(description: "Connection callback called")
        let received1 = expectation(description: "UDP data received 1/3")
        let received2 = expectation(description: "UDP data received 2/3")
        let received3 = expectation(description: "UDP data received 3/3")

        let receiveQueue = DispatchQueue(label: "receiving")
        
        guard let listener = try? NWListener(using: .udp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
            
            // In this test, we send 1024 bytes using netcat.
            // We then read the bytes using two receives (1 bytes and 1023 bytes).
            newConn.receive(minimumIncompleteLength: 1, maximumLength: 1)
            {
                (maybeData, maybeContext, isComplete, maybeError) in
                
                guard let receivedData1 = maybeData else
                {
                    XCTFail("Empty data received")
                    return
                }
                print(receivedData1.count)
                
                XCTAssertEqual(receivedData1.count, 1)
                
                received1.fulfill()
                
                newConn.receive(minimumIncompleteLength: 1023, maximumLength: 1023)
                {
                    (maybeData, maybeContext, isComplete, maybeError) in
                    
                    guard let receivedData2 = maybeData else
                    {
                        XCTFail("Empty data received")
                        return
                    }
                    print(receivedData2.count)
                    
                    XCTAssertEqual(receivedData2.count, 1023)
                    
                    received2.fulfill()
                    
                    newConn.receive(minimumIncompleteLength: 100, maximumLength: 100)
                    {
                        (maybeData, maybeContext, isComplete, maybeError) in
                        
                        guard let receivedData3 = maybeData else
                        {
                            XCTFail("Empty data received")
                            return
                        }
                        print(receivedData3.count)
                        
                        XCTAssertEqual(receivedData3.count, 100)
                        
                        received3.fulfill()
                    }
                }
            }
            
            // You have to call start on the new connection
            newConn.start(queue: receiveQueue)
        }
        listener.start(queue: receiveQueue)
        
        wait(for: [connected, received1, received2, received3], timeout: 10)
    }
    
    func testUDPMultipacketSpanningSmallReceive()
    {
        let connected = expectation(description: "Connection callback called")
        let received1 = expectation(description: "UDP data received 1/3")
        let received2 = expectation(description: "UDP data received 2/3")
        let received3 = expectation(description: "UDP data received 3/3")
        
        let receiveQueue = DispatchQueue(label: "receiving")
        
        guard let listener = try? NWListener(using: .udp, on: 5555) else
        {
            XCTFail("Listener failed")
            return
        }
        listener.newConnectionHandler={
            (newConn: NWConnection) in
            
            print("newConn \(newConn)")
            connected.fulfill()
            
            // In this test, we send 1024 bytes using netcat.
            // We then read the bytes using two receives (1 bytes and 1023 bytes).
            newConn.receive(minimumIncompleteLength: 1000, maximumLength: 1000)
            {
                (maybeData, maybeContext, isComplete, maybeError) in
                
                guard let receivedData1 = maybeData else
                {
                    XCTFail("Empty data received")
                    return
                }
                print(receivedData1.count)
                
                XCTAssertEqual(receivedData1.count, 1000)
                
                received1.fulfill()
                
                newConn.receive(minimumIncompleteLength: 1000, maximumLength: 1000)
                {
                    (maybeData, maybeContext, isComplete, maybeError) in
                    
                    guard let receivedData2 = maybeData else
                    {
                        XCTFail("Empty data received")
                        return
                    }
                    print(receivedData2.count)
                    
                    // Note that this will be a short read because it's on a packet boundary.
                    // minimumIncompleteLength is ignored.
                    XCTAssertEqual(receivedData2.count, 24)
                    
                    received2.fulfill()
                    
                    newConn.receive(minimumIncompleteLength: 1024, maximumLength: 1024)
                    {
                        (maybeData, maybeContext, isComplete, maybeError) in
                        
                        guard let receivedData3 = maybeData else
                        {
                            XCTFail("Empty data received")
                            return
                        }
                        print(receivedData3.count)
                        
                        XCTAssertEqual(receivedData3.count, 1024)
                        
                        received3.fulfill()
                    }
                }
            }
            
            // You have to call start on the new connection
            newConn.start(queue: receiveQueue)
        }
        listener.start(queue: receiveQueue)
        
        wait(for: [connected, received1, received2, received3], timeout: 10)
    }
    
    func testUDPLargeSendInternet()
    {
        let sent = expectation(description: "UDP data sent")
        
        let sendQueue = DispatchQueue(label: "sending")
        
        // Maximum UDP size for some reason is 9216. Larger than this and the test will throw and error
        // However, not all 9216 bytes will be received by the server when sent over the Internet.
        // In tests using a remote server and netcat, 2048 bytes were received.
        let data = Data(repeating: 0x40, count: 9216)
        let dataSize = data.count
        
        let conn = NWConnection(host: NWEndpoint.Host("166.78.129.122"), port: NWEndpoint.Port(integerLiteral: 5555), using: .udp)
        conn.start(queue: sendQueue)
        
        conn.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({
            (maybeError) in
            
            guard maybeError == nil else
            {
                XCTFail("Error sending")
                return
            }
            
            sent.fulfill()
        }))
        
        wait(for: [sent], timeout: 10)
    }
    
    func testUDPLargeSend()
    {
        let sent = expectation(description: "UDP data sent")
        
        let sendQueue = DispatchQueue(label: "sending")
        
        // Maximum UDP size for some reason is 9216. Larger than this and the test will throw and error
        // However, not all 9216 bytes will be received by the server when sent over the Internet.
        // In tests using a remote server and netcat, 2048 bytes were received.
        // In tests using a local server and netcat, 1024 bytes were received.
        let data = Data(repeating: 0x40, count: 9216)
        let dataSize = data.count
        
        let conn = NWConnection(host: NWEndpoint.Host("localhost"), port: NWEndpoint.Port(integerLiteral: 5555), using: .udp)
        conn.start(queue: sendQueue)
        
        conn.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({
            (maybeError) in
            
            guard maybeError == nil else
            {
                XCTFail("Error sending")
                return
            }
            
            sent.fulfill()
        }))
        
        wait(for: [sent], timeout: 10)
    }
}
