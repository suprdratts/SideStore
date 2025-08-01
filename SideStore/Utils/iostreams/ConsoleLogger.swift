//
//  ConsoleCapture.swift
//  AltStore
//
//  Created by Magesh K on 25/11/24.
//  Copyright © 2024 SideStore. All rights reserved.
//

import Foundation

protocol ConsoleLogger{
    func startCapturing()
    func stopCapturing()
}

public class AbstractConsoleLogger<T: OutputStream>: ConsoleLogger{
    var outPipe: Pipe?
    var errPipe: Pipe?
    
    var outputHandle: FileHandle?
    var errorHandle:  FileHandle?
    
    var originalStdout: Int32?
    var originalStderr: Int32?
    
    let ostream: T
    
    let writeQueue = DispatchQueue(label: "async-write-queue")
    
    public init(stream: T) throws {
        // Since swift doesn't support compile time abstract classes Instantiation checking,
        // we are using runtime check to prevent direct instantiation :(
        if Self.self === AbstractConsoleLogger.self {
            throw AbstractClassError.abstractInitializerInvoked
        }
        
        self.ostream = stream
    }
    
    deinit {
        stopCapturing()
    }
    
    public func startCapturing() {                          // made it public coz, let client ask for capturing

        // if already initialized within current instance, bail out
        guard outPipe == nil, errPipe == nil else {
            return
        }
        
        // Create new pipes for stdout and stderr
        self.outPipe = Pipe()
        self.errPipe = Pipe()
        
        outputHandle = self.outPipe?.fileHandleForReading
        errorHandle = self.errPipe?.fileHandleForReading

        // Store original file descriptors
        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)
        
        let redirectedOutStream = self.outPipe?.fileHandleForWriting.fileDescriptor ?? -1
        let redirectedErrStream = self.errPipe?.fileHandleForWriting.fileDescriptor ?? -1
        
        // Redirect stdout and stderr to our pipes
        dup2(redirectedOutStream, STDOUT_FILENO)
        dup2(redirectedErrStream, STDERR_FILENO)

        // Disable libc-level buffering
        // (libc by default uses bufferring except its own console/TTYs such as for pipes)
        // we do have our own buffering so we disable stdlib io level bufferring
        setvbuf(stdout, nil, _IONBF, 0)  // disable buffering for stdout
        setvbuf(stderr, nil, _IONBF, 0)  // disable buffering for stderr
        
        // Setup readability handlers for raw data
        setupReadabilityHandler(for: outputHandle, isError: false)
        setupReadabilityHandler(for: errorHandle, isError: true)
    }

    let shutdownLock = NSLock()

    private func setupReadabilityHandler(for handle: FileHandle?, isError: Bool) {
        handle?.readabilityHandler = readHandler(for: handle, isError: isError)
    }

    private func readHandler(for handle: FileHandle?, isError: Bool) -> (FileHandle) -> Void {
        return { [weak self] _ in
            guard let self, let data = handle?.availableData else { return }

            shutdownLock.lock()
            defer { shutdownLock.unlock() }

            writeQueue.async {
                try? self.writeData(data)
            }

            if let fd = isError ? self.originalStderr : self.originalStdout {
                data.withUnsafeBytes { _ = write(fd, $0.baseAddress, $0.count) }
            }
        }
    }

    
    func writeData(_ data: Data) throws {
        throw AbstractClassError.abstractMethodInvoked
    }

    func stopCapturing() {
        shutdownLock.lock()
        defer { shutdownLock.unlock() }

        ostream.close()
        
        // Restore original stdout and stderr
        if let stdout = originalStdout, stdout != STDOUT_FILENO {
            dup2(stdout, STDOUT_FILENO)
            close(stdout)
        }
        if let stderr = originalStderr, stderr != STDERR_FILENO {
            dup2(stderr, STDERR_FILENO)
            close(stderr)
        }
        
        // Clean up
        outPipe?.fileHandleForReading.readabilityHandler = nil
        errPipe?.fileHandleForReading.readabilityHandler = nil
        outPipe = nil
        errPipe = nil
        outputHandle = nil
        errorHandle = nil
        originalStdout = nil
        originalStderr = nil
    }
}


public class UnBufferedConsoleLogger<T: OutputStream>: AbstractConsoleLogger<T> {

    required override init(stream: T) {
        // cannot throw abstractInitializerInvoked, so need to override else client needs to handle it unnecessarily
        try! super.init(stream: stream)
    }
    
    override func writeData(_ data: Data) throws {
        // directly write data to the stream without buffering
        ostream.write(data)
    }
}

public class BufferedConsoleLogger<T: OutputStream>: AbstractConsoleLogger<T> {

    // Buffer size (bytes) and storage
    private let maxBufferSize: Int
    private var bufferedData = Data()
    
    required init(stream: T, bufferSize: Int = 1024) {
        self.maxBufferSize = bufferSize
        try! super.init(stream: stream)
    }
    
    override func writeData(_ data: Data) throws {
        // Append data to buffer
        self.bufferedData.append(data)
        
        // Check if the buffer is full and flush
        if self.bufferedData.count >= self.maxBufferSize {
            self.flushBuffer()
        }
    }
    
    private func flushBuffer() {
        // Write all buffered data to the stream
        ostream.write(bufferedData)
        bufferedData.removeAll()
    }

    override func stopCapturing() {
        // Flush buffer and close the file handles first
        flushBuffer()
        super.stopCapturing()
    }
}
