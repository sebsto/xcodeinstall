//
//  Test.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 26/10/2024.
//

import Testing
import SRP

@Suite("SRPKeysTestCase")
struct SRPKeysTestCase {
    @Test func base64() async throws {
        //given
        let keyRawMaterial: [UInt8] = [1,2,3,4,5,6,7,8,9, 10]
        let key = SRPKey(keyRawMaterial)
        #expect(key.bytes == keyRawMaterial)
        
        //when
        let b64Key = key.base64
        let newKey = SRPKey(base64: b64Key)
        
        //then
        #expect(newKey != nil)
        #expect(newKey?.bytes == keyRawMaterial)
    }
}

