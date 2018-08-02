//
//  Mneumonic.swift
//  BigInt
//
//  Created by Cole Potrocky on 8/1/18.
//

import BigInt
import CryptoSwift
import Result

public final class Mnemonic {
  
  public struct MnemonicSentence {
    public let language: WordList.Language
    public let sentence: [String]
  }
  
  // The longer the sentence, the higher the security.
  public enum SentenceLengthInWords: UInt {
    case twelve = 12
    case fifteen = 15
    case eighteen = 18
    case twentyOne = 21
    case twentyFour = 24
    
    var entropyInBits: Int {
      switch self {
      case .twelve:
        return 128
      case .fifteen:
        return 160
      case .eighteen:
        return 192
      case .twentyOne:
        return 224
      case .twentyFour:
        return 256
      }
    }
  }
  
  public static func create(with length: SentenceLengthInWords, language: WordList.Language) -> MnemonicSentence {
    let byteCount = length.entropyInBits / 8
    var bytes = Data(count: byteCount)
    _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, byteCount, $0) }
    
    return create(randomBytes: bytes, language: language)
  }
  
  public static func createSeed(
    from mnemonic: MnemonicSentence,
    passPhrase: String = ""
  ) -> Result<Data, AnyError> {
    do {
      let bytes = try PKCS5.PBKDF2(
        password: mnemonic.sentence.joined(separator: " ").bytes,
        salt: "mnemonic\(passPhrase)".bytes,
        iterations: 2048,
        variant: .sha512
      ).calculate()
      
      return .success(Data(bytes: bytes))
    } catch { error
      // Error here could be: PKCS5.PBKDF2.Error | HMAC.Error, but keeping it general
      // just in case CryptoSwift were to change from under us for any reason.
      return .failure(AnyError(error))
    }
  }
  
  // MARK: Private API
  
  static func create(randomBytes: Data, language: WordList.Language) -> MnemonicSentence {
    let mnemonicSequence: [Bit] = {
      let checksumLength = randomBytes.count / 4
      let checksum = Array(randomBytes.sha256().bits[0..<checksumLength])
      
      var bits = randomBytes.bits
      bits.append(contentsOf: checksum)
      return bits
    }()
    
    let wordList: [String] = {
      var list = WordList(language: language)
      return list.wordList
    }()
    
    return MnemonicSentence(
      language: language,
      sentence: mnemonicSequence.chunks(11).map {
        let key = Int(bits: $0.reversed())
        return wordList[key]
      }
    )
  }
}

