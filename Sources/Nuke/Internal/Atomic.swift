// The MIT License (MIT)
//
// Copyright (c) 2015-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

// memo: Lock（レースコンディション対策）機構
final class Atomic<T>: @unchecked Sendable {
    private var _value: T
    private let lock: os_unfair_lock_t

    init(value: T) {
        self._value = value
        // memo: os_unfair_lock_s構造体１個分のメモリを確保してそのポインタを返却
        self.lock = .allocate(capacity: 1)
        // memo: 確保したメモリにアンロック状態(0)で初期化
        // (状態値 ≠ 0）の場合は、ロック状態
        self.lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    var value: T {
        get {
            // memo: ロックを取得（通常は状態値にスレッドIDが入る）
            // 自分よりも先にlockが取得されている場合はロックが解放されるまで待機
            os_unfair_lock_lock(lock)
            defer { os_unfair_lock_unlock(lock) }
            return _value
        }
        set {
            os_unfair_lock_lock(lock)
            defer { os_unfair_lock_unlock(lock) }
            _value = newValue
        }
    }

    func withLock<U>(_ closure: (inout T) -> U) -> U {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return closure(&_value)
    }
}
