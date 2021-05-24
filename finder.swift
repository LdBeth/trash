import Foundation
import AppKit

fileprivate func getFinderPID() -> pid_t {
    for app in NSWorkspace.shared.runningApplications {
        if app.bundleIdentifier == "com.apple.finder" {
            return app.processIdentifier
        }
    }
    return -1
}

enum FinderError: Error {
    case failedToMkDesc, failedToSend, failedGetReply, notAllFilesTrashed
}

func askFinderToMoveFilesToTrash(files: [URL],
                                 bringFinderToFront: Bool) throws {
    let urlListDescr = NSAppleEventDescriptor(listDescriptor: ())
    var i = 1
    for filePath in files {
        guard let descr = NSAppleEventDescriptor(
                descriptorType: typeFileURL,
                data: filePath.absoluteString.data(using: String.Encoding.utf8)
              ) else {
            throw FinderError.failedToMkDesc
        }
        urlListDescr.insert(descr, at: i)
        i += 1
    }
    var finderPID = getFinderPID()
    let targetDesc = NSAppleEventDescriptor(
      descriptorType: typeKernelProcessID,
      bytes: &finderPID,
      length: MemoryLayout<pid_t>.size
    )
    let descriptor = NSAppleEventDescriptor.appleEvent(
      withEventClass: kCoreEventClass,
      eventID: 1684368495, // 'delo'
      targetDescriptor: targetDesc,
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )
    descriptor.setDescriptor(
      urlListDescr,
      forKeyword: 757935405 // '----'
    )
    var replyEvent = AppleEvent()
    let sendErr = AESendMessage(
      descriptor.aeDesc, &replyEvent, AESendMode(kAEWaitReply),
      kAEDefaultTimeout)
    if sendErr != noErr {
        throw FinderError.failedToSend
    }

    var replyAEDesc = AEDesc()
    let getReplyErr = AEGetParamDesc(&replyEvent, keyDirectObject, typeWildCard, &replyAEDesc)
    if getReplyErr != noErr {
        // DEBUG: reply failed
        print("\(getReplyErr),\(replyAEDesc)")
        throw FinderError.failedGetReply
    }
    let replyDesc = NSAppleEventDescriptor(aeDescNoCopy: &replyAEDesc)
    if replyDesc.numberOfItems == 0
         || (1 < files.count && (replyDesc.descriptorType != typeAEList
                                   || replyDesc.numberOfItems != files.count))
    { throw FinderError.notAllFilesTrashed }
}
