//
//  File.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation
import CLIlib

/**
 
 Implement xcode download without authentication
 
 curl -v "https://developerservices2.apple.com/services/download?path=/Developer_Tools/Xcode_14.1/Xcode_14.1.xip"
 < HTTP/1.1 200 OK
 < Server: Apple
 < Date: Thu, 13 Oct 2022 05:24:27 GMT
 < Content-Length: 0
 < Connection: keep-alive
 < Set-Cookie: ADCDownloadAuth=bDHjRR3cAxlCeJgSzPhJ%2B%2FByRrwhWtFpeZ9AMDT0h1abSQBBn5wvLK%2ByJwwxld%2BODoDoVB%2B8yszA%0D%0AV%2Bivz8XWhNcM9Gttbp6MMI0UEkmr3wAJVbGgnv2ZEfoezZQgozj5LiTR7wFa%2FNmMI0oaSTqeRjKt%0D%0AkXVJ%2BJgqd7yZfuImBRtGcV9c%0D%0A;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;HttpOnly;Expires=Thu, 13 Oct 2022 05:24:27 GMT
 
 curl -v "https://developerservices2.apple.com/services/download?path=/Developer_Tools/Command_Line_Tools_for_Xcode_14/Command_Line_Tools_for_Xcode_14.dmg"
 
 < HTTP/1.1 200 OK
 < Server: Apple
 < Date: Sat, 22 Oct 2022 04:54:51 GMT
 < Content-Length: 0
 < Connection: keep-alive
 < Set-Cookie: ADCDownloadAuth=ictAKIPaVGjh5a5yQdvDpxjX9Ld%2BjLmZQ3xBay5ydN8nUjzxtZRELOXNbfPcbM32XwsKKf3Bn1aR%0D%0AHVAOzC%2Foiac0kLwd4nPigBjbpgRkGRtAc2auSHwDlrlZDcIcTX8oWDLe70H3MnrHO0UxfMe1JFmJ%0D%0ATIm6T%2BaxZHaLX5CuXxoNDT3K%0D%0A;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;HttpOnly;Expires=Sat, 22 Oct 2022 04:54:51 GMT
 < Host: developerservices2.apple.com
 < X-Frame-Options: SAMEORIGIN
 < Strict-Transport-Security: max-age=31536000; includeSubdomains
 < wwdr-vip-rqId: c5366d52047751f4eb7ef5bb59056b73
 
 
 curl -vL0 --cookie ADCDownloadAuth=ILyY%2FDe2y2gp7a6PONIbwDHrBK3WAWTyiE6H7hEjyHCrlqHNnes4CBSPob0S35%2Fe1gV4TvlISZLn%0D%0AY9%2FlkRd9m2%2BInEISwAo5Qmr1hzHVyWUJ6cawQzJbar7aG%2FlYjC%2F%2FCDUjHzhYLytb8eM8rmG53Hlf%0D%0AeMcVnDdbbjzK5PAz9mt2%2BKZg%0D%0A --output Xcode_14.1.xip "https://download.developer.apple.com/Developer_Tools/Xcode_14.1/Xcode_14.1.xip"
 
 
 */

protocol ApplePackageDownloaderProtocol {
    func listAvailableDownloads() async throws -> AvailableDownloadList
    func download(_ package: Package, with delegate: AppleDownloadDelegate) async throws -> URL
}

struct ApplePackageDownloader: ApplePackageDownloaderProtocol {

    let appleAuthCookieName = "ADCDownloadAuth"

    func listAvailableDownloads() async throws -> AvailableDownloadList {
        
        var result : AvailableDownloadList
        
        // download available files list
        let (data, urlResponse) = try await env.api.data(for: .availableDowloads())
        
        // verify we received a valid HTTP response
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            fatalError("API call did not return an HTTP Response")
        }
        guard httpResponse.statusCode == 200 else {
            throw AppleAvailableDownloadsError.invalidHTTPResponse
        }
        
        // parse file
        result = try AvailableDownloadList(withData: data)
        
        // filter out entries that are relevant to Xcode only
        // this should be anything with Xcode in the name
        result.list = result.list.filter { download in
            return download.name.contains("Xcode")
        }
            
        return result
    }

    // this function replaces the AppleDownloader Class
    // the download delegate does not use a Semaphore anymore. It uses callbacks instead
    // see https://stackoverflow.com/questions/73664619/how-to-correctly-await-a-swift-callback-closure-result
    func download(_ package: Package, with delegate: AppleDownloadDelegate) async throws -> URL {

        log.debug("Requesting authentication cookie")
        let cookie = try await self.authenticationCookie(for: package)
        
        // call our API
        log.debug("Starting the download")
        let task = env.api.download(for: .appleDownloadRequest(for: package, with: cookie), delegate: delegate)
        task.resume()
        
        return try await withCheckedThrowingContinuation { continuation in
            
            // the download delegate will call the callback when download ends
            // here I just create the function that resume the `await` call with an error or success
            delegate.callback = { result in
                
                switch result {
                case .failure(let error):
                    continuation.resume(throwing: error)

                case .success(let url):
                    continuation.resume(returning: url)
                }
            }
        }

    }
        
    //MARK: private functions
    
    // separate function for easier unit testing
    // func is not private for unit testing
    func authenticationCookie(for package: Package) async throws -> HTTPCookie {
        
        let (_, urlResponse) = try await env.api.data(for: .appleAuthenticationRequest(for: package))
        
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            fatalError("API call did not return an HTTP Response")
        }
        guard httpResponse.statusCode == 200 else {
            throw AppleAPIError.invalidPackage(package: package, urlResponse: httpResponse)
        }
        
        // delegate cookie extraction for easier unit testing
        return try self.appleAuthCookie(from: httpResponse)
    }

    // separate function for easier unit testing
    // func is not private for unit testing
    func appleAuthCookie(from response: HTTPURLResponse) throws -> HTTPCookie {
                
        guard let cookie = response.value(forHTTPHeaderField: "Set-Cookie") else {
            throw AppleAPIError.noCookie
        }
        
        // do not pass httpResponse.allheadersFields because HTTPCookie.cookies() expects [String:String]
        let fakeHeader = ["Set-Cookie": cookie]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fakeHeader,
                                         for: URL(string: "https://apple.com")!)
        
        // extract ADCDownloadAuth cookie
        let authCookie = cookies.filter { cookie in cookie.name == appleAuthCookieName }
        
        guard authCookie.count == 1 else {
            throw AppleAPIError.noCookie
        }
        
        return authCookie[0]
    }

}
