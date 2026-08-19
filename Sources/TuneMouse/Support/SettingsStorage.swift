import Foundation

/// 설정의 UserDefaults(JSON) 영속화 공통 처리.
///
/// 예전엔 `try?`로 실패를 통째로 삼켰다. 그러면 두 가지가 조용히 일어난다:
/// 손상되거나 미래 버전의 저장본을 만나면 아무 흔적 없이 기본값으로 리셋되고
/// **바로 다음 변경이 원본을 덮어써 영영 복구 불가**가 되며, 저장 실패는 아무도 모른 채
/// 설정이 사라진다. 그래서 실패를 로그로 남기고, 읽지 못한 데이터는 덮어쓰기 전에 백업한다.
enum SettingsStorage {
    /// 읽기 실패 시 원본을 옮겨 둘 키의 접미사.
    private static let backupSuffix = ".corrupted"

    static func load<T: Decodable>(_ type: T.Type, key: String, label: String) -> T where T: Encodable, T: DefaultInitializable {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return T() // 최초 실행 — 정상 경로
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // 원본 보존: 다음 저장이 덮어쓰기 전에 백업해 둔다(사용자 데이터 복구 여지).
            let backupKey = key + backupSuffix
            UserDefaults.standard.set(data, forKey: backupKey)
            Log.app.error("""
                \(label, privacy: .public) 읽기 실패 — 기본값으로 시작합니다. \
                기존 데이터는 '\(backupKey, privacy: .public)' 키에 보존했습니다. \
                (\(error.localizedDescription, privacy: .public))
                """)
            return T()
        }
    }

    static func save<T: Encodable>(_ value: T, key: String, label: String) {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            Log.app.error("\(label, privacy: .public) 저장 실패 — 변경이 유지되지 않습니다: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// 기본값으로 생성 가능한 설정 타입(읽기 실패 시 폴백에 필요).
protocol DefaultInitializable {
    init()
}
