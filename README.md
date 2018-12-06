# NetworkExperiments

This project documents the undocumented semantics of Apple's Network framework.

## NWListener

### Handling New Connections

Handling new connections is done by registered a callback function on the listener's newConnectionHandler property.

```
let listenQueue = DispatchQueue(label: "listener")
let connQueue = DispatchQueue(label: "incoming connection")

listener.newConnectionHandler={
    (newConn: NWConnection) in

    print("newConn \(newConn)")
    
    newConn.start(queue: connQueue)
}
listener.start(queue: listenQueue)
```

Note that you must call start() on both the listener and the new connection.
If you do not call start() on the new connection, you will not be able to send or receive data.

#### UDP Connections

UDP is a connectionless protocol. However, the only way to deal with incoming data for a server is to use the newConnectionHandler callback. So when is this called for incoming UDP packets?

The newConnectionHandler callback is called whenever a UDP data packet is received with a host-port pair which has not yet been seen since the server was started.

## NWConnection

### TCP

#### Send

You can send data of any size using the send() function and the Network framework will buffer it for you. No limitations on data size were discovered so far during testing.

#### Receive

You can receive data of any size using the receive() function's minimumIncompleteLength: parameter and the Network framework will buffer for you. No limitations on data size were discovered so far during testing.

### UDP

#### Send

When sending data, the if the size of the data is greater than 9216 byte, the send() function will throw an error. However, this limit is already greater than the maximum UDP packet size. During testing, when calling send() with larger data, the data was truncated and only some of it arrived at the server. Using netcat as a local server, only 1024 bytes were received and using netcat on a remote server over the Internet only 2048 bytes were received.

More testing is necessary to discover what the Network framework is doing. Is it fragmenting the data into multiple UDP packets, only some of which make it to the server? Is it truncating the data to a fixed size, which for some reason is larger when connecting to a remote server rather than a local one? Regardless, the only safe choice for an application
is to limit calls to send() to data with a maximum size of 1024 bytes.

#### Receive

The Network framework will buffer received UDP packets, allowing for reads shorter than the size of the received UDP packet. For instance, a netcat client can send 1024 bytes. The application can then read this in two separate receive() calls, first with a minimumIncompleteLength of 1 and then with a minimumIncompleteLength of 1023.

However, the behavior is different for reads which are longer than the received UDP packet. receive() cannot cross UDP packet boundaries. For instance, imagine if two UDP packets are received, each consisting of 1024 bytes. If the application were then to attempt to read 1000 bytes, then 1000 bytes, then 48 bytes, the actual returned data lengths would be 1000, 24, and 48. The first two reads are taken from the first 1024 byte packet. The second read cannot cross the packet boundary, so it comes up short, returning just 24 bytes instead of the requested 1000. So in the case of UDP, the minimumIncompleteLength: parameter is ignored if there are not enough bytes in the current packet and the rest of the bytes are returned, whatever size they might be.

The benefit of this approach to the application developer is that UDP packet boundaries can be discovered by always making large reads. For instance, if 3000 bytes are requested for the minimumIncompleteLength: parameters to receive(), then a smaller number of bytes will be returned (likely a maximum of 1024) and this number is the actual size of the UDP packet. This is in fact apparently the most reasonable way to use the Network framework receive() function as other usage patterns, for instance reading the packet 1 byte at a time, will not reveal packet boundaries.
