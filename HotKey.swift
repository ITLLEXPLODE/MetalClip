import Cocoa
import Carbon

// MARK: - HotKey 구조체
// 어떤 키 조합인지 표현
struct HotKey: Equatable {
    let keyCode: UInt32        // 키보드 키 (예: 19 = 숫자 '2')
    let modifiers: UInt32      // Cmd, Shift, Option, Ctrl 조합
    
    // 사람이 읽을 수 있는 형식 (예: "⇧⌘2")
    var displayString: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0  { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0   { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0     { result += "⌘" }
        result += HotKey.keyCodeToString(keyCode)
        return result
    }
    
    // 키 코드를 문자로 변환 (간단 버전 — 나중에 확장)
    static func keyCodeToString(_ code: UInt32) -> String {
        switch code {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 15: return "R"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 37: return "L"
        default: return "Key\(code)"
        }
    }
}

// MARK: - HotKey Manager
// 핫키 등록/해제 담당
class HotKeyManager {
    private var registeredHotKeys: [UInt32: (HotKey, () -> Void)] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var eventHandler: EventHandlerRef?
    
    init() {
        installEventHandler()
    }
    
    // 핫키 등록 — 누르면 action 실행
    func register(_ hotKey: HotKey, action: @escaping () -> Void) {
        let id = nextHotKeyID
        nextHotKeyID += 1
        
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D434C50), id: id)  // 'MCLP'
        var hotKeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            registeredHotKeys[id] = (hotKey, action)
            print("⌨️ 핫키 등록: \(hotKey.displayString)")
        } else {
            print("❌ 핫키 등록 실패: \(hotKey.displayString) (status: \(status))")
        }
    }
    
    // 핫키 핸들러 설치 (한 번만)
    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let event = event, let userData = userData else { return noErr }
                
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                if let (_, action) = manager.registeredHotKeys[hotKeyID.id] {
                    DispatchQueue.main.async {
                        action()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }
}
