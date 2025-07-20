//
//  SideStoreClient.swift
//  AltStore
//
//  Created by s s on 2025/7/20.
//  Copyright © 2025 SideStore. All rights reserved.
//
import AltStoreCore

@objc extension SideStoreClient {
    
    @objc func performRefreshForReal(server: any RefreshServer) {
        Task {
            do {
                let progress = Progress(totalUnitCount: 1)
                progress.completedUnitCount = 0
                var observation = progress.observe(\.fractionCompleted, options: [.new]) { progress, change in
                    if let newValue = change.newValue {
                        server.updateProgress(newValue)
                    }
                }
                
                
                try await refreshAllApps(progress: progress)
                server.finish(nil)
            } catch {
                server.finish(error.localizedDescription)
            }
            

        }
    }
    
    @objc func refreshAllApps(progress: Progress) async throws
    {
        if !DatabaseManager.shared.isStarted
        {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                DatabaseManager.shared.start { error in
                    if let error
                    {
                        continuation.resume(throwing: error)
                    }
                    else
                    {
                        continuation.resume()
                    }
                }
            }
        }
        
        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        let installedApps = await context.perform { InstalledApp.fetchAppsForRefreshingAll(in: context) }
        
        try await withCheckedThrowingContinuation { continuation in
            let operation = AppManager.shared.backgroundRefresh(installedApps, presentsNotifications: true) { (result) in
                do
                {
                    let results = try result.get()
                    
                    for (_, result) in results
                    {
                        guard case let .failure(error) = result else { continue }
                        throw error
                    }
                    
                    continuation.resume()
                }
                catch ~RefreshErrorCode.noInstalledApps
                {
                    continuation.resume()
                }
                catch
                {
                    continuation.resume(throwing: error)
                }
            }
            
            operation.ignoresServerNotFoundError = false
            
            progress.addChild(operation.progress, withPendingUnitCount: 1)
            
        }
    }
}
